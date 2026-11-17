-- Pure playback calculations, independent of a network or Kindle framebuffer.
local M = {}
function M.minute_bars(duration_ms, progress_ms)
    duration_ms = math.max(0, tonumber(duration_ms) or 0)
    if duration_ms > 8*60*60*1000 then return {}, 'duration_too_long' end
    progress_ms = math.max(0, math.min(duration_ms, tonumber(progress_ms) or 0))
    local total = math.ceil(duration_ms / 60000)
    local lit = math.min(total, math.floor(progress_ms / 60000))
    if duration_ms > 0 and progress_ms >= duration_ms then lit = total end
    local result = {}
    for i = 1, total do result[i] = i <= lit end
    return result
end
function M.seek_for_bar(index, duration_ms)
    local count = math.ceil(math.max(0, duration_ms or 0) / 60000)
    if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > count then return nil end
    return (index - 1) * 60000
end
function M.transport_action(is_playing)
    return is_playing and 'pause' or 'play'
end
return M
