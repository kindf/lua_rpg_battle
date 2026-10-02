local Log = {}
Log.depth = 0
Log.enabled = true
Log.show_back = true

local function pad()
    return string.rep("  ", Log.depth)
end

function Log.section(title)
    Log.depth = 0
    if Log.enabled then
        print("")
        print(string.rep("=", 62))
        print("== " .. title)
        print(string.rep("=", 62))
    end
end

function Log.fn(name, note)
    if Log.enabled then
        print(pad() .. "-> " .. name .. (note and ("  #" .. note) or ""))
    end
    Log.depth = Log.depth + 1
end

function Log.back(ret)
    Log.depth = Log.depth - 1
    if Log.enabled and Log.show_back then
        print(pad() .. "<- return " .. tostring(ret))
    end
end

function Log.msg(text)
    if Log.enabled then
        print(pad() .. "   " .. text)
    end
end

function Log.warn(text)
    if Log.enabled then
        print(pad() .. "   [!]" .. text)
    end
end

function Log.error(text)
    if Log.enabled then
        print(pad() .. "   [X]" .. text)
    end
end

return Log
