local currentRace, raceData
local isSpectator = false
local checkpoints = {}
local currentCheckpointIndex = 0
local currentLap = 1
local showUI = false
local startTime = 0
local finished = false

local function debug(msg)
    if Config.Debug then
        print(('^2[cg-streetracing]^7 %s'):format(msg))
    end
end

local function clearCheckpoints()
    for _, data in ipairs(checkpoints) do
        if data.blip and DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
    end
    checkpoints = {}
end

local function setupCheckpoints(race)
    clearCheckpoints()
    for i, pos in ipairs(race.checkpoints) do
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, Config.CheckpointBlip.sprite)
        SetBlipColour(blip, Config.CheckpointBlip.colour)
        SetBlipScale(blip, Config.CheckpointBlip.scale)
        ShowNumberOnBlip(blip, i)
        checkpoints[i] = {pos = pos, blip = blip}
    end
end

local function drawCheckpoint(index)
    local cp = checkpoints[index]
    if not cp then return end
    local pos = cp.pos
    DrawMarker(
        Config.CheckpointMarker.type,
        pos.x, pos.y, pos.z - 1.0,
        0.0,0.0,0.0, 0.0,0.0,0.0,
        Config.CheckpointMarker.scale.x, Config.CheckpointMarker.scale.y, Config.CheckpointMarker.scale.z,
        Config.CheckpointMarker.color.r, Config.CheckpointMarker.color.g, Config.CheckpointMarker.color.b, Config.CheckpointMarker.color.a,
        false,false,2,false,nil,nil,false
    )
end

local function timeNowMs()
    return GetGameTimer()
end

local function openUI()
    if showUI then return end
    showUI = true
    SendNUIMessage({action='show'})
end

local function closeUI()
    if not showUI then return end
    showUI = false
    SendNUIMessage({action='hide'})
end

local function resetState()
    clearCheckpoints()
    currentRace = nil
    raceData = nil
    isSpectator = false
    finished = false
    currentCheckpointIndex = 0
    currentLap = 1
end

local function updateTimeLoop()
    CreateThread(function()
        while showUI and currentRace and not finished do
            local elapsed = timeNowMs() - startTime
            SendNUIMessage({action='time', time = elapsed})
            Wait(200)
        end
    end)
end

RegisterNetEvent('cg-streetracing:client:raceCreated', function(raceId, race)
    lib.notify({title='Street Race', description='Race created: '..race.label..' ('..raceId..')', type='success'})
end)

RegisterNetEvent('cg-streetracing:client:joinedRace', function(raceId, race)
    currentRace = raceId
    raceData = race
    isSpectator = false
    lib.notify({title='Street Race', description='Joined race '..race.label, type='inform'})
    setupCheckpoints(race)
    currentCheckpointIndex = 0
    currentLap = 1
    finished = false
    openUI()
    updateTimeLoop()
end)

RegisterNetEvent('cg-streetracing:client:raceStarted', function(raceId, sTime)
    if currentRace ~= raceId then return end
    startTime = sTime
    lib.notify({title='Street Race', description='Race started! Go!', type='success'})
end)

RegisterNetEvent('cg-streetracing:client:spectating', function(raceId, header)
    currentRace = raceId
    raceData = header
    isSpectator = true
    openUI()
    lib.notify({title='Street Race', description='Spectating '..(header.label or raceId), type='inform'})
end)

RegisterNetEvent('cg-streetracing:client:finished', function(raceId, finishTime)
    if currentRace ~= raceId then return end
    finished = true
    SendNUIMessage({action='finished'})
    lib.notify({title='Street Race', description='You finished! Time '..finishTime, type='success'})
end)

RegisterNetEvent('cg-streetracing:client:raceEnded', function(raceId, ordered, summary)
    if currentRace ~= raceId then return end
    lib.notify({title='Street Race', description='Race ended', type='inform'})
    if summary then
        SendNUIMessage({action='summary', data = summary})
    end
    closeUI()
    resetState()
end)

RegisterNetEvent('cg-streetracing:client:updatePositions', function(list)
    if not currentRace then return end
    SendNUIMessage({action='positions', list = list, me = GetPlayerServerId(PlayerId())})
end)

CreateThread(function()
    while true do
    if currentRace and raceData and raceData.started and not finished and not isSpectator then
            local nextIndex = currentCheckpointIndex + 1
            local cp = checkpoints[nextIndex]
            if cp then
                local ped = PlayerPedId()
                local pcoords = GetEntityCoords(ped)
                local dist = #(pcoords - cp.pos)
                drawCheckpoint(nextIndex)
                if dist < 5.0 then
                    currentCheckpointIndex = nextIndex
                    TriggerServerEvent('cg-streetracing:server:checkpoint', currentRace, currentCheckpointIndex, {x=pcoords.x, y=pcoords.y, z=pcoords.z})
                    if currentCheckpointIndex >= raceData.total then
                        if raceData.laps and raceData.laps > currentLap then
                            currentLap = currentLap + 1
                            currentCheckpointIndex = 0
                            SendNUIMessage({action='lap', lap=currentLap, laps=raceData.laps})
                        end
                    end
                end
            end
        end
        Wait(0)
    end
end)

RegisterCommand('createrace', function(_, args)
    local key = args[1] or 'test_loop'
    ESX.TriggerServerCallback('cg-streetracing:createRace', function(success, raceId, dataOrReason)
        if not success then
            lib.notify({title='Street Race', description='Create failed: '..tostring(dataOrReason), type='error'})
        else
            debug('CreateRace callback ok '..raceId)
        end
    end, key)
end)
RegisterCommand('joinrace', function(_, args)
    local raceId = args[1]
    if not raceId then
        lib.notify({title='Street Race', description='Usage: /joinrace <id>', type='error'})
        return
    end
    ESX.TriggerServerCallback('cg-streetracing:joinRace', function(success, rid, raceOrReason)
        if not success then
            lib.notify({title='Street Race', description='Join failed: '..tostring(raceOrReason), type='error'})
        end
    end, raceId)
end)
RegisterCommand('startrace', function(_, args)
    local raceId = args[1]
    if not raceId then
        lib.notify({title='Street Race', description='Usage: /startrace <id>', type='error'})
        return
    end
    ESX.TriggerServerCallback('cg-streetracing:startRace', function(success, ridOrReason)
        if not success then
            lib.notify({title='Street Race', description='Start failed: '..tostring(ridOrReason), type='error'})
        end
    end, raceId)
end)

RegisterCommand('spectaterace', function(_, args)
    local raceId = args[1]
    if not raceId then
        lib.notify({title='Street Race', description='Usage: /spectaterace <id>', type='error'})
        return
    end
    ESX.TriggerServerCallback('cg-streetracing:spectateRace', function(success, ridOrReason)
        if not success then
            lib.notify({title='Street Race', description='Spectate failed: '..tostring(ridOrReason), type='error'})
        end
    end, raceId)
end)

RegisterCommand('leaverace', function()
    if not currentRace then
        lib.notify({title='Street Race', description='No active race / spectate', type='error'})
        return
    end
    ESX.TriggerServerCallback('cg-streetracing:leaveRace', function(success, ridOrReason)
        if not success then
            lib.notify({title='Street Race', description='Leave failed: '..tostring(ridOrReason), type='error'})
        end
    end, currentRace)
    SendNUIMessage({action='hideAll'})
    closeUI()
    resetState()
end)

RegisterCommand('hideraceui', function()
    SendNUIMessage({action='hideAll'})
    closeUI()
end)

RegisterNetEvent('cg-streetracing:client:forceHide', function()
    SendNUIMessage({action='hideAll'})
    closeUI()
    resetState()
end)

CreateThread(function()
    local zone = Config.RaceTerminal
    exports.ox_target:addBoxZone({
        coords = zone.coords,
        size = zone.size,
        rotation = 0,
        debug = zone.debug,
        options = {
            {
                name = 'cg_race_menu',
                icon = 'fa-solid fa-flag-checkered',
                label = 'Street Racing',
                onSelect = function()
                    lib.notify({title='Street Race', description='Use /createrace test_loop', type='inform'})
                end
            }
        }
    })
end)
