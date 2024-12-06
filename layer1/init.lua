local signal = require("../utility/signal.lua")

local Layer1 = {}
Layer1.__index = Layer1

function Layer1.new(startPort: Port?)
    if not startPort then
        error("startPort cannot be nil")
    end
    local self = setmetatable({}, Layer1)
    self.MTU = 2^16
    self.ListenEVENT = signal.new()
    self.blacklistPorts = {}
    self.startPort = startPort
    self.newMicros = {}
    self:updateMicroList()
    self:startListening()
    return self
end

function Layer1:addBlacklistPort(port: Port)
    self.blacklistPorts[port] = true
end

function Layer1:removeBlacklistPort(port: Port)
    self.blacklistPorts[port] = nil
end

local function mergeTable(t1: {[any]: any}, t2: {[any]: any})
    for k, v in pairs(t2) do
        t1[k] = v
    end
end

function Layer1:send(buf: buffer)
    if buffer.len(buf) > self.MTU then
        error("Buffer exceeds Layer1 MTU")
    end
    for _, micro in pairs(self.newMicros) do
        micro:Send(buf)
    end
end

function Layer1:indexMicro()
    local micros = {}
    local stack = {self.startPort}
    local seenPorts = {}
    local function markSeen(port: Port?)
        seenPorts[port] = true
    end
    local function portSeen(port: Port?): boolean
        return seenPorts[port]
    end
    markSeen(self.startPort)
    while #stack > 0 do
        local currentPort = table.remove(stack)
        if not self.blacklistPorts[currentPort] then
            local foundmicros = GetPartsFromPort(currentPort, "Microcontroller")
            table.find(foundmicros, Microcontroller) -- Remove ourselves from the list
            mergeTable(micros, foundmicros)
            local ports = GetPartsFromPort(currentPort, "Port")
            for _, port in pairs(ports) do
                if not portSeen(port) then
                    markSeen(port)
                    table.insert(stack, port)
                end
            end
        end
    end
    return micros
end

function Layer1:updateMicroList()
    self.newMicros = self:indexMicro()
end

function Layer1:startListening()
    task.defer(function()
        while true do
            pcall(function()
                self:updateMicroList()
            end)
            task.wait(1)
        end
    end)
    task.defer(function()
        while task.wait() do
            local senderMicro, buf:buffer = Microcontroller:Receive()
            if typeof(buf) == "buffer" then
                self.ListenEVENT:Fire(senderMicro, buf)
            end
        end
    end)
end

return Layer1