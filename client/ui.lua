-- Placeholder for extended UI logic if needed later
-- Currently main UI interactions handled in main.lua

local M = {}

function M.FormatTime(ms)
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local centiseconds = math.floor((ms % 1000) / 10)
    return string.format('%02d:%02d:%02d', minutes, seconds, centiseconds)
end

return M
