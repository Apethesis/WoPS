local layer2 = require('../layer2')
local signal = require('../utility/signal.lua')
local u48 = require('../utility/u48.lua')
local conf = require('conf.lua')

local dhcp = {}
dhcp.EVENT = signal.new()

local DHCP_IDENTIFIER = 0x80

-- Message Types
local DHCP_DISCOVER = 1
local DHCP_OFFER = 2
local DHCP_REQUEST = 3
local DHCP_ACK = 4
local DHCP_NAK = 5
local DHCP_RELEASE = 6

-- Packet structure: [IDENTIFIER(1)] [TYPE(1)] [CLIENT_MAC(6)] [IP(4)]
local function encodePacket(msgType, clientMAC, ip)
    local buf = buffer.create(12)
    buffer.writeu8(buf, 0, DHCP_IDENTIFIER)
    buffer.writeu8(buf, 1, msgType)
    u48.write(buf, 2, clientMAC)
    if ip then
        buffer.writeu32(buf, 8, ip)
    end
    return buf
end

local function decodePacket(buf)
    if buffer.len(buf) < 8 then return nil end
    if buffer.readu8(buf, 0) ~= DHCP_IDENTIFIER then return nil end
    
    local msgType = buffer.readu8(buf, 1)
    local clientMAC = u48.read(buf, 2)
    local ip = buffer.len(buf) >= 12 and buffer.readu32(buf, 8) or nil
    return msgType, clientMAC, ip
end

function dhcp.discover()
    local packet = {
        src = layer2.MAC,
        dst = layer2.BROADCAST,  -- Broadcast to find DHCP server
        data = encodePacket(DHCP_DISCOVER, layer2.MAC)
    }
    layer2.send(packet)
end

function dhcp.release()
    if not conf.IP then return end
    
    local packet = {
        src = layer2.MAC,
        dst = layer2.BROADCAST,
        data = encodePacket(DHCP_RELEASE, layer2.MAC, conf.IP)
    }
    layer2.send(packet)
    conf.IP = nil
end

layer2.ListenEVENT:Connect(function(sender, packet)
    local success, msgType, clientMAC, ip = pcall(decodePacket, packet.data)
    if not success or not msgType then return end
    if clientMAC ~= layer2.MAC then return end -- Not for us

    if msgType == DHCP_OFFER then
        local requestPacket = {
            src = layer2.MAC,
            dst = packet.src,
            data = encodePacket(DHCP_REQUEST, layer2.MAC, ip)
        }
        layer2.send(requestPacket)
        
    elseif msgType == DHCP_ACK then
        conf.IP = ip
        dhcp.EVENT:Fire(ip)
        
    elseif msgType == DHCP_NAK then
        task.wait(1)
        dhcp.discover()
    end
end)

return dhcp