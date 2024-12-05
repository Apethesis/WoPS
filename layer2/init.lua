local layer1 = require('../layer1')
local u48 = require('../utility/u48.lua')
local signal = require('../utility/signal.lua')
local Layer2 = {}

Layer2.MTU = layer1.MTU - 12 -- 12 bytes for src(6) + dst(6) MAC addresses
Layer2.ListenEVENT = signal.new()
type Packet = {
    src: number, -- u48 (6 bytes)
    dst: number, -- u48 (6 bytes)
    data: buffer
}

-- Broadcast MAC address (all 1's)
Layer2.BROADCAST = u48.max
Layer2.MAC = 0

function Layer2.encode(packet: Packet): buffer
    local offset = 0
    local obuf = buffer.create(buffer.len(packet.data) + 12)
    
    u48.write(obuf, offset, packet.src)
    offset += 6
    
    u48.write(obuf, offset, packet.dst)
    offset += 6
    
    buffer.copy(obuf, offset, packet.data)
    
    return obuf
end

function Layer2.decode(ibuf: buffer): Packet
    if buffer.len(ibuf) < 12 then -- min frame
        error("Buffer too small for Layer2 packet")
    end
        
    local offset = 0
    
    local src = u48.read(ibuf, offset)
    offset += 6
    
    local dst = u48.read(ibuf, offset)
    offset += 6
    
    local dataLen = buffer.len(ibuf) - offset
    local data = buffer.create(dataLen)
    buffer.copy(data, 0, ibuf, offset, dataLen)
    
    return {
        src = src,
        dst = dst,
        data = data
    }
end

function Layer2.setMAC(mac: number)
    if type(mac) ~= "number" or mac < 0 or mac > u48.max then
        error("Invalid MAC address")
    end
    Layer2.MAC = mac
end

function Layer2.send(packet: Packet)
    if not Layer2.MAC then
        error("Layer2 MAC address not set")
    end
    
    if packet.src ~= Layer2.MAC then
        error("Invalid source MAC address")
    end
    
    if not Layer2.isValidPacket(packet) then
        error("Invalid Layer2 packet")
    end
    
    local encoded = Layer2.encode(packet)
    layer1.send(encoded)
end

function Layer2.isValidPacket(packet: Packet): boolean
    if not packet or type(packet) ~= "table" then return false end
    if type(packet.src) ~= "number" or packet.src < 0 or packet.src > u48.max then return false end
    if type(packet.dst) ~= "number" or packet.dst < 0 or packet.dst > u48.max then return false end
    if not packet.data or buffer.len(packet.data) > Layer2.MTU then return false end
    return true
end

layer1.ListenEVENT:Connect(function(senderMicro: Microcontroller, buf: buffer)
    local success, packet = pcall(Layer2.decode, buf)
    if success and Layer2.isValidPacket(packet) then
        Layer2.ListenEVENT:Fire(senderMicro, packet)
    end
end)

return Layer2