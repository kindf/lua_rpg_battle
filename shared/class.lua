local function class(name, base)
    local cls = {}
    cls.__index = cls
    cls.__name = name
    if base then
        cls.__base = base
        setmetatable(cls, {__index = base})
    end
    function cls.new(...)
        local obj = setmetatable({}, cls)
        if obj._init then obj:_init(...) end
        return obj
    end
    return cls
end

return { class = class }
