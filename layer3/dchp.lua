local signal = require('../utility/signal.lua')
local u48 = require('../utility/u48.lua')
local conf = require('conf.lua')

local DHCP = {}
DHCP.__index = DHCP

local DHCP_IDENTIFIER = 0x80

-- Message Types
local DHCP_DISCOVER = 1
local DHCP_OFFER = 2
local DHCP_REQUEST = 3
local DHCP_ACK = 4
local DHCP_NAK = 5
local DHCP_RELEASE = 6

-- Packet structure: [IDENTIFIER(1)] [TYPE(1)] [CLIENT_MAC(6)] [IP(4)]
function DHCP:encodePacket(msgType, clientMAC, ip)
    local buf = buffer.create(12)
    buffer.writeu8(buf, 0, DHCP_IDENTIFIER)
    buffer.writeu8(buf, 1, msgType)
    u48.write(buf, 2, clientMAC)
    if ip then
        buffer.writeu32(buf, 8, ip)
    end
    return buf
end

function DHCP:decodePacket(buf)
    if buffer.len(buf) < 8 then return nil end
    if buffer.readu8(buf, 0) ~= DHCP_IDENTIFIER then return nil end

    local msgType = buffer.readu8(buf, 1)
    local clientMAC = u48.read(buf, 2)
    local ip = buffer.len(buf) >= 12 and buffer.readu32(buf, 8) or nil
    return msgType, clientMAC, ip
end

function DHCP.new(layer2Instance)
    local self = setmetatable({}, DHCP)
    self.layer2 = layer2Instance
    self.EVENT = signal.new()

    -- Subscribe to Layer2's ListenEVENT
    self.layer2.ListenEVENT:Connect(function(sender, packet)
        local success, msgType, clientMAC, ip = pcall(function()
            return self:decodePacket(packet.data)
        end)
        if not success or not msgType then return end
        if clientMAC ~= self.layer2.MAC then return end -- Not for us

        if msgType == DHCP_OFFER then
            local requestPacket = {
                src = self.layer2.MAC,
                dst = packet.src,
                data = self:encodePacket(DHCP_REQUEST, self.layer2.MAC, ip)
            }
            self.layer2:send(requestPacket)

        elseif msgType == DHCP_ACK then
            conf.IP = ip
            self.EVENT:Fire(ip)

        elseif msgType == DHCP_NAK then
            task.wait(1)
            self:discover()
        end
    end)

    return self
end

function DHCP:discover()
    local packet = {
        src = self.layer2.MAC,
        dst = self.layer2.BROADCAST,  -- Broadcast to find DHCP server
        data = self:encodePacket(DHCP_DISCOVER, self.layer2.MAC)
    }
    self.layer2:send(packet)
end

function DHCP:release()
    if not conf.IP then return end

    local packet = {
        src = self.layer2.MAC,
        dst = self.layer2.BROADCAST,
        data = self:encodePacket(DHCP_RELEASE, self.layer2.MAC, conf.IP)
    }
    self.layer2:send(packet)
    conf.IP = nil
end

return DHCP