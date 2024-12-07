local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({
        _connections = {}
    }, Signal)

    return self
end

function Signal:Connect(callback)
    table.insert(self._connections, callback)

    local cleaned = false

    return function() -- I got lzzy
        if cleaned then
            return
        end

        table.remove(self._connections, table.find(self._connections, callback))
    end
end

function Signal:Wait()
    local thread = coroutine.running()

    local cleanupConnection
    cleanupConnection = self:Connect(function(...)
        cleanupConnection()
        coroutine.resume(thread, ...)
    end)

    return coroutine.yield()
end

function Signal:Fire(...)
    for _, callback in self._connections do
        task.spawn(callback, ...)
    end
end

return Signal