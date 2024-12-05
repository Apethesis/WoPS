local layer2 = require('../layer2')
local hash32 = require('../utility/hash.lua')
local discover = require("discover.lua")
local conf = require("conf.lua")
local Layer3 = {}

local function tonum(num)
    return tonumber(num,2)
end

Layer3._VERSION = tonum("00000100") -- 4
Layer3.MTU = layer2.MTU - 18
type Packet = {
    len: number | nil, --u16
    ttl: number, --u8
    prot: number, --u8
    flags: number?, --u16
    chck: number?, --u32
    src: number, --u32
    dst: number, --u32
    data: buffer, --u8[]
    valid: boolean?, --decode only
}

function Layer3.encode(packet: Packet): buffer
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

function Layer3.decode(ibuf: buffer): Packet
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


function Layer3.isValidPacket(ibuf: buffer): boolean
    if buffer.len(ibuf) < 19 then -- min header
        return false
    end
    
    local offset = 0
    local version = buffer.readu8(ibuf, offset)
    if version ~= Layer3._VERSION then
        return false
    end
    
    offset += 3 -- ignore flags
    local len = buffer.readu16(ibuf, offset)
    if len ~= buffer.len(ibuf) then
        return false
    end
    
    offset += 2
    local ttl = buffer.readu8(ibuf, offset)
    if ttl == 0 then
        return false
    end
    
    offset += 6 -- protocol and checksum irrelevant
    local src = buffer.readu32(ibuf, offset)
    offset += 4
    local dst = buffer.readu32(ibuf, offset)
    
    if src == 0 or dst == 0 then
        return false
    end
    
    return true
end

return Layer3