local Layer3 = {}
Layer3.__index = Layer3

local hash32 = require('../utility/hash.lua')
local signal = require('../utility/signal.lua')
local Layer2 = require('../layer2')
Layer3._VERSION = tonumber("00000100", 2) -- Version 4

type Packet = {
    len: number?,    -- u16
    ttl: number,     -- u8
    prot: number,    -- u8
    flags: number?,  -- u16
    chck: number?,   -- u32
    src: number,     -- u32
    dst: number,     -- u32
    data: buffer,    -- u8[]
    valid: boolean?, -- decode only
}

function Layer3.new(layer2Instance)
    local self = setmetatable({}, Layer3)
    self.layer2 = layer2Instance
    self.MTU = self.layer2.MTU - 18  -- Adjust MTU based on Layer2
    self.ListenEVENT = signal.new()

    -- Subscribe to Layer2's ListenEVENT
    self.layer2.ListenEVENT:Connect(function(senderMicro, frame)
        local success, packet = pcall(function() return self:decode(frame.data) end)
        if success and self:isValidPacket(packet) then
            self.ListenEVENT:Fire(senderMicro, packet)
        end
    end)

    return self
end

function Layer3:encode(packet: Packet): buffer
    local offset = 0
    local headerSize = 1 + 2 + 2 + 1 + 4 + 1 + 4 + 4
    local obuf = buffer.create(buffer.len(packet.data) + headerSize)

    buffer.writeu8(obuf, offset, Layer3._VERSION); offset += 1
    buffer.writeu16(obuf, offset, packet.flags or 0); offset += 2
    buffer.writeu16(obuf, offset, buffer.len(obuf)); offset += 2
    buffer.writeu8(obuf, offset, packet.ttl); offset += 1

    local chckPos = offset
    buffer.writeu32(obuf, offset, 0); offset += 4

    buffer.writeu8(obuf, offset, packet.prot); offset += 1
    buffer.writeu32(obuf, offset, packet.src); offset += 4
    buffer.writeu32(obuf, offset, packet.dst); offset += 4

    buffer.copy(obuf, offset, packet.data); offset += buffer.len(packet.data)

    buffer.writeu32(obuf, chckPos, hash32(obuf))

    return obuf
end

function Layer3:decode(ibuf: buffer): Packet
    local offset = 0
    local version = buffer.readu8(ibuf, offset); offset += 1
    if version ~= Layer3._VERSION then
        error("Version mismatch")
    end

    local flags = buffer.readu16(ibuf, offset); offset += 2
    local len = buffer.readu16(ibuf, offset); offset += 2
    local ttl = buffer.readu8(ibuf, offset); offset += 1

    local chckPos = offset
    local chck = buffer.readu32(ibuf, offset); offset += 4

    local prot = buffer.readu8(ibuf, offset); offset += 1
    local src = buffer.readu32(ibuf, offset); offset += 4
    local dst = buffer.readu32(ibuf, offset); offset += 4

    local dataLen = buffer.len(ibuf) - offset
    local data = buffer.create(dataLen)
    buffer.copy(data, 0, ibuf, offset, dataLen)

    -- Verify checksum
    local bufferCopy = buffer.create(buffer.len(ibuf))
    buffer.copy(bufferCopy, 0, ibuf, 0, buffer.len(ibuf))
    buffer.writeu32(bufferCopy, chckPos, 0)
    local computedChck = hash32(bufferCopy)
    local valid = (chck == computedChck)

    return {
        len = len,
        flags = flags,
        ttl = ttl,
        prot = prot,
        chck = chck,
        src = src,
        dst = dst,
        data = data,
        valid = valid
    }
end

function Layer3:isValidPacket(packet: Packet): boolean
    if not packet or type(packet) ~= "table" then return false end
    if packet.len ~= buffer.len(packet.data) + 20 then return false end
    if packet.ttl <= 0 then return false end
    if packet.src == 0 or packet.dst == 0 then return false end
    if packet.valid == false then return false end
    return true
end

function Layer3:send(packet: Packet)
    if not self:isValidPacket(packet) then
        error("Invalid Layer3 packet")
    end

    local encoded = self:encode(packet)

    self.layer2:send({
        src = self.layer2.MAC,
        dst = Layer2.BROADCAST,
        data = encoded
    })
end

return Layer3