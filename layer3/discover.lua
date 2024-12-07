local u48 = require('../utility/u48.lua')

local Discover = {}
Discover.__index = Discover

function Discover.new(layer3Instance)
    local self = setmetatable({}, Discover)
    self.layer2 = layer3Instance.layer2
    self.cache = {} -- {[ip: number]: {mac: number, timestamp: number}}

    self.CACHE_TIMEOUT = 5 -- seconds
    self.TYPE_REQUEST = 1
    self.TYPE_RESPONSE = 2

    -- Subscribe to Layer2's ListenEVENT
    self.layer2.ListenEVENT:Connect(function(sender, packet)
        local success, ptype, ip, mac = pcall(function()
            return self:decodePacket(packet.data)
        end)
        if not success then return end

        if ptype == self.TYPE_REQUEST then
            if ip == conf.IP then
                -- Respond with our MAC address
                local responsePacket = {
                    src = self.layer2.MAC,
                    dst = packet.src,
                    data = self:encodePacket(self.TYPE_RESPONSE, ip, self.layer2.MAC)
                }
                self.layer2:send(responsePacket)
            end
        elseif ptype == self.TYPE_RESPONSE then
            -- Update cache with IP-MAC mapping
            self:updateCache(ip, mac)
        end
    end)

    return self
end

function Discover:encodePacket(ptype: number, ip: number, mac: number): buffer
    local buf = buffer.create(12) -- 1 byte protocol ID + 1 byte type + 4 bytes IP + 6 bytes MAC
    buffer.writeu8(buf, 0, 127) -- Discover protocol ID
    buffer.writeu8(buf, 1, ptype)
    buffer.writeu32(buf, 2, ip)
    u48.write(buf, 6, mac)
    return buf
end

function Discover:decodePacket(buf: buffer): (number, number, number)
    local protocolId = buffer.readu8(buf, 0)
    if protocolId ~= 127 then
        error('Invalid protocol ID')
    end
    local ptype = buffer.readu8(buf, 1)
    local ip = buffer.readu32(buf, 2)
    local mac = u48.read(buf, 6)
    return ptype, ip, mac
end

function Discover:updateCache(ip: number, mac: number)
    self.cache[ip] = {mac = mac, timestamp = os.time()}
end

function Discover:isValidCache(ip: number): boolean
    local entry = self.cache[ip]
    return entry and (os.time() - entry.timestamp <= self.CACHE_TIMEOUT)
end

function Discover:get(targetIp: number): number?
    if self:isValidCache(targetIp) then
        return self.cache[targetIp].mac
    end

    self:request(targetIp)

    local startTime = os.time()
    while os.time() - startTime < 1 do -- 1 second timeout
        if self:isValidCache(targetIp) then
            return self.cache[targetIp].mac
        end
        task.wait()
    end

    return nil
end

function Discover:request(targetIp: number)
    local packet = {
        src = self.layer2.MAC,
        dst = self.layer2.BROADCAST,
        data = self:encodePacket(self.TYPE_REQUEST, targetIp, self.layer2.MAC)
    }
    self.layer2:send(packet)
end

return Discover