local Config = require 'config'
local ESX = exports['es_extended']:getSharedObject()

--- Race storage
local Races = {}
-- Active players: raceId -> { [source] = {checkpoint = 0, lap = 1, finished = false, startTime = 0, finishTime = nil} }
local RacePlayers = {}
-- Spectators: raceId -> { [source] = true }
local RaceSpectators = {}
local BestTimesCache = {}

-- Initialize DB table for best times
CreateThread(function()
    if not MySQL then
        debug('oxmysql not found (Best time persistence disabled)')
        return
    end
    MySQL.query([[CREATE TABLE IF NOT EXISTS cg_race_times (
        id INT AUTO_INCREMENT PRIMARY KEY,
        race_key VARCHAR(64) NOT NULL,
        identifier VARCHAR(64) NOT NULL,
        player_name VARCHAR(128) NOT NULL,
        best_time INT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_race_player (race_key, identifier)
    )]], {}, function()
        debug('Ensured table cg_race_times exists')
    end)
end)

local function loadBestTime(raceKey, identifier)
    local cacheKey = raceKey .. '|' .. identifier
    if BestTimesCache[cacheKey] ~= nil then return BestTimesCache[cacheKey] end
    if not MySQL then return nil end
    local result = MySQL.query.await('SELECT best_time FROM cg_race_times WHERE race_key = ? AND identifier = ?', {raceKey, identifier})
    if result and result[1] then
        BestTimesCache[cacheKey] = result[1].best_time
        return result[1].best_time
    end
    return nil
end

local function saveBestTime(raceKey, identifier, name, timeMs)
    if not MySQL then return end
    local cacheKey = raceKey .. '|' .. identifier
    local existing = loadBestTime(raceKey, identifier)
    if existing and existing <= timeMs then return existing end
    if existing then
        MySQL.update('UPDATE cg_race_times SET best_time = ?, player_name = ? WHERE race_key = ? AND identifier = ?', {timeMs, name, raceKey, identifier})
    else
        MySQL.insert('INSERT INTO cg_race_times (race_key, identifier, player_name, best_time) VALUES (?,?,?,?)', {raceKey, identifier, name, timeMs})
    end
    BestTimesCache[cacheKey] = timeMs
    return timeMs
end

local function debug(msg)
    if Config.Debug then
        print(('^3[cg-streetracing]^7 %s'):format(msg))
    end
end

local function formatTime(ms)
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local millis = ms % 1000
    return string.format('%02d:%02d:%02d', minutes, seconds, math.floor(millis / 10))
end

local function buildPositions(raceId)
    local players = RacePlayers[raceId]
    if not players then return {} end
    local list = {}
    for src, data in pairs(players) do
        local ck = (data.lap - 1) * (Races[raceId].total) + data.checkpoint -- overall progress across laps
        local cpTime = data.lastCheckpointTime or data.startTime
        if data.finished then
            ck = 999999 -- put finished at top ordered by finishTime
            cpTime = data.finishTime or cpTime
        end
        list[#list+1] = {
            source = src,
            checkpoint = ck,
            time = cpTime,
            finished = data.finished,
            finishTime = data.finishTime,
            name = data.name,
            lap = data.lap
        }
    end
    table.sort(list, function(a,b)
        if a.finished and b.finished then
            return (a.finishTime or 0) < (b.finishTime or 0)
        elseif a.finished ~= b.finished then
            return a.finished
        end
        if a.checkpoint == b.checkpoint then
            return a.time < b.time
        end
        return a.checkpoint > b.checkpoint
    end)
    return list
end

local function broadcastPositions(raceId)
    local posList = buildPositions(raceId)
    for _, entry in ipairs(posList) do
        TriggerClientEvent('cg-streetracing:client:updatePositions', entry.source, posList)
    end
    -- spectators also receive updates
    if RaceSpectators[raceId] then
        for src,_ in pairs(RaceSpectators[raceId]) do
            TriggerClientEvent('cg-streetracing:client:updatePositions', src, posList)
        end
    end
end

local function endRace(raceId)
    local players = RacePlayers[raceId]
    if not players then return end
    local ordered = buildPositions(raceId)
    -- Build summary with placements & DNF
    local summary = {}
    local race = Races[raceId]
    for place, entry in ipairs(ordered) do
        local pdata = players[entry.source]
        local totalTime = pdata and pdata.finishTime and (pdata.finishTime - race.startTime) or nil
        summary[#summary+1] = {
            place = place,
            name = entry.name or ('Player '..entry.source),
            finished = entry.finished,
            time = totalTime
        }
    end
    -- Include DNFs (players not finished when race forced to end)
    for src, pdata in pairs(players) do
        if not pdata.finished then
            summary[#summary+1] = { place = #summary+1, name = pdata.name or ('Player '..src), finished = false, time = nil, dnf = true }
        end
    end
    for place, entry in ipairs(ordered) do
        local src = entry.source
        local pdata = players[src]
        if pdata and pdata.finished and place == 1 then
            -- payout winner only for now
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                local race = Races[raceId]
                xPlayer.addAccountMoney('money', race.payout or 0, 'Street Race Win')
            end
        end
        TriggerClientEvent('cg-streetracing:client:raceEnded', src, ordered, summary)
    end
    -- send summary to spectators too
    if RaceSpectators[raceId] then
        for src,_ in pairs(RaceSpectators[raceId]) do
            TriggerClientEvent('cg-streetracing:client:raceEnded', src, ordered, summary)
        end
    end
    Races[raceId] = nil
    RacePlayers[raceId] = nil
    RaceSpectators[raceId] = nil
    debug(('Race %s ended'):format(raceId))
end

local function scheduleDNF(raceId)
    local race = Races[raceId]
    if not race then return end
    if race.dnfTimer then return end
    race.dnfTimer = SetTimeout(Config.AutoDNFTimeSeconds * 1000, function()
        endRace(raceId)
    end)
end

RegisterNetEvent('cg-streetracing:server:createRace', function(raceKey)
    local src = source
    local raceCfg = Config.Races[raceKey]
    if not raceCfg then
        return TriggerClientEvent('ox_lib:notify', src, {type='error', title='Street Race', description='Race not found'})
    end
    local raceId = ('%s-%d'):format(raceKey, os.time())
    Races[raceId] = {
        key = raceKey,
        label = raceCfg.label,
        checkpoints = raceCfg.checkpoints,
        total = #raceCfg.checkpoints,
        payout = raceCfg.payout,
        laps = raceCfg.laps or 1,
        createdBy = src,
        started = false,
        startTime = 0
    }
    RacePlayers[raceId] = {}
    RaceSpectators[raceId] = {}
    TriggerClientEvent('cg-streetracing:client:raceCreated', src, raceId, Races[raceId])
    debug(('Race created %s by %d'):format(raceId, src))
end)

RegisterNetEvent('cg-streetracing:server:joinRace', function(raceId)
    local src = source
    local race = Races[raceId]
    if not race then
        return TriggerClientEvent('ox_lib:notify', src, {type='error', title='Street Race', description='Race does not exist'})
    end
    if race.started then
        return TriggerClientEvent('ox_lib:notify', src, {type='error', title='Street Race', description='Race already started'})
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    local name = xPlayer and (xPlayer.getName and xPlayer:getName() or xPlayer.name) or ('Player '..src)
    RacePlayers[raceId][src] = {
        checkpoint = 0,
        lap = 1,
        finished = false,
        startTime = 0,
        lastCheckpointTime = 0,
        name = name
    }
    TriggerClientEvent('cg-streetracing:client:joinedRace', src, raceId, race)
    debug(('Player %d joined race %s'):format(src, raceId))
end)

RegisterNetEvent('cg-streetracing:server:startRace', function(raceId)
    local src = source
    local race = Races[raceId]
    if not race then return end
    if race.createdBy ~= src then return end
    if race.started then return end
    local players = RacePlayers[raceId]
    local count = 0
    for _ in pairs(players) do count = count + 1 end
    if count < Config.MinPlayersToStart then
        return TriggerClientEvent('ox_lib:notify', src, {type='error', title='Street Race', description='Not enough players'})
    end
    race.started = true
    race.startTime = os.clock() * 1000
    for playerSrc, pdata in pairs(players) do
        pdata.startTime = race.startTime
        TriggerClientEvent('cg-streetracing:client:raceStarted', playerSrc, raceId, race.startTime)
    end
    debug(('Race %s started with %d players'):format(raceId, count))
end)

RegisterNetEvent('cg-streetracing:server:checkpoint', function(raceId, checkpointIndex, playerCoords)
    local src = source
    local race = Races[raceId]
    if not race or not race.started then return end
    local pdata = RacePlayers[raceId] and RacePlayers[raceId][src]
    if not pdata or pdata.finished then return end
    if Config.StrictOrder and checkpointIndex ~= pdata.checkpoint + 1 then
        return -- invalid sequence / possible exploit
    end
    -- Distance validation (anti-exploit)
    if playerCoords and Config.CheckpointMaxDistance then
        local nextCkPos = race.checkpoints[checkpointIndex]
        if nextCkPos then
            local dx = nextCkPos.x - playerCoords.x
            local dy = nextCkPos.y - playerCoords.y
            local dz = nextCkPos.z - playerCoords.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist > Config.CheckpointMaxDistance then
                debug(('Reject checkpoint %d for %d (dist %.2f)'):format(checkpointIndex, src, dist))
                return
            end
        end
    end
    pdata.checkpoint = checkpointIndex
    pdata.lastCheckpointTime = os.clock() * 1000

    if pdata.checkpoint >= race.total then
        -- Lap or finish
        if pdata.lap < race.laps then
            pdata.lap = pdata.lap + 1
            pdata.checkpoint = 0 -- reset for next lap
            debug(('Player %d starting lap %d/%d'):format(src, pdata.lap, race.laps))
        else
            pdata.finished = true
            pdata.finishTime = pdata.lastCheckpointTime
            scheduleDNF(raceId)
            debug(('Player %d finished race %s'):format(src, raceId))
            TriggerClientEvent('cg-streetracing:client:finished', src, raceId, pdata.finishTime)
            -- persistence best time
            local xPlayer = ESX.GetPlayerFromId(src)
            local identifier = xPlayer and (xPlayer.getIdentifier and xPlayer:getIdentifier() or xPlayer.identifier) or ('steam:'..src)
            local newBest = saveBestTime(race.key, identifier, pdata.name or ('Player '..src), pdata.finishTime - race.startTime)
            if newBest then
                TriggerClientEvent('ox_lib:notify', src, {type='success', title='Street Race', description='New best time: '..formatTime(newBest)})
            end
            -- check if everyone finished or only one left
            local still = 0
            for _, d in pairs(RacePlayers[raceId]) do
                if not d.finished then still = still + 1 end
            end
            if still == 0 then
                endRace(raceId)
                return
            end
        end
    end
    broadcastPositions(raceId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for raceId, players in pairs(RacePlayers) do
        if players[src] then
            players[src] = nil
            broadcastPositions(raceId)
        end
    end
    for raceId, specs in pairs(RaceSpectators) do
        if specs[src] then
            specs[src] = nil
        end
    end
end)

-- Spectate existing race (late join viewing only)
RegisterNetEvent('cg-streetracing:server:spectateRace', function(raceId)
    local src = source
    if not Config.AllowLateSpectate then return end
    local race = Races[raceId]
    if not race or not race.started then
        return TriggerClientEvent('ox_lib:notify', src, {type='error', title='Street Race', description='Race not active'})
    end
    RaceSpectators[raceId][src] = true
    TriggerClientEvent('cg-streetracing:client:spectating', src, raceId, {label = race.label, laps = race.laps, total = race.total})
    -- push immediate positions
    local posList = buildPositions(raceId)
    TriggerClientEvent('cg-streetracing:client:updatePositions', src, posList)
end)

-- Export for debug listing
exports('ListRaces', function() return Races end)
