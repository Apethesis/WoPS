local Layer2 = {}
Layer2.__index = Layer2

local u48 = require('../utility/u48.lua')
local signal = require('../utility/signal.lua')

local function generateRandomMAC()
    -- Generate 6 random bytes
    local b1 = math.random(0, 255)
    local b2 = math.random(0, 255)
    local b3 = math.random(0, 255)
    local b4 = math.random(0, 255)
    local b5 = math.random(0, 255)
    local b6 = math.random(0, 255)
    b1 = bit32.band(b1, 0xFE)
    b1 = bit32.bor(b1, 0x02)

    return bit32.bor(
        bit32.lshift(b1, 40),
        bit32.lshift(b2, 32),
        bit32.lshift(b3, 24),
        bit32.lshift(b4, 16),
        bit32.lshift(b5, 8),
        b6
    )
end

-- Broadcast MAC address (all 1's)
Layer2.BROADCAST = u48.max

type Packet = {
    src: number,
    dst: number,
    data: buffer
}

function Layer2.new(layer1Instance)
    local self = setmetatable({}, Layer2)
    self.layer1 = layer1Instance
    self.MTU = self.layer1.MTU - 12 -- 12 bytes for src(6) + dst(6) MAC addresses
    self.ListenEVENT = signal.new()
    self.MAC = generateRandomMAC()

    -- Subscribe to layer1's ListenEVENT
    self.layer1.ListenEVENT:Connect(function(senderMicro, buf)
        local success, packet = pcall(function() return self:decode(buf) end)
        if success and self:isValidPacket(packet) then
            self.ListenEVENT:Fire(senderMicro, buf, packet)
        else
            print("packet is not valid what the wtf")
        end
    end)
    return self
end

function Layer2:setMAC(mac)
    if type(mac) ~= "number" or mac < 0 or mac > u48.max then
        error("Invalid MAC address")
    end
    self.MAC = mac
end

function Layer2:encode(packet: Packet): buffer
    local offset = 0
    local obuf = buffer.create(buffer.len(packet.data) + 12)
    
    u48.write(obuf, offset, packet.src)
    offset = offset + 6
    
    u48.write(obuf, offset, packet.dst)
    offset = offset + 6
    
    buffer.copy(obuf, offset, packet.data)
    
    return obuf
end

function Layer2:decode(ibuf: buffer): Packet
    if buffer.len(ibuf) < 12 then -- min frame
        error("Buffer too small for Layer2 packet")
    end
        
    local offset = 0
    
    local src = u48.read(ibuf, offset)
    offset = offset + 6
    
    local dst = u48.read(ibuf, offset)
    offset = offset + 6
    
    local dataLen = buffer.len(ibuf) - offset
    local data = buffer.create(dataLen)
    buffer.copy(data, 0, ibuf, offset, dataLen)
    
    return {
        src = src,
        dst = dst,
        data = data
    }
end

function Layer2:send(packet: Packet)
    if not self.MAC then
        error("Layer2 MAC address not set")
    end
    
    --if packet.src ~= self.MAC then
    --    error("Invalid source MAC address") -- this wouldnt work on the switch haha troll
    --end
    
    if not self:isValidPacket(packet) then
        error("Invalid Layer2 packet")
    end
    
    local encoded = self:encode(packet)
    self.layer1:send(encoded)
end

function Layer2:isValidPacket(packet: Packet): boolean
    if not packet or type(packet) ~= "table" then return false end
    if type(packet.src) ~= "number" or packet.src < 0 or packet.src > u48.max then return false end
    if type(packet.dst) ~= "number" or packet.dst < 0 or packet.dst > u48.max then return false end
    if not packet.data or buffer.len(packet.data) > self.MTU then return false end
    return true
end

return Layer2