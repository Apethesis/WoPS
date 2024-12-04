local layer2 = require('../layer2')
local hash32 = require('../utility/hash.lua')
local Layer3 = {}

local ARP_cache = {}


Layer3.MTU = layer2.MTU - 16
type Packet = {
    --len: number, --u16
    ttl: number, --u8
    prot: number, --u8
    chck: number?, --u32
    src: number, --u32
    dst: number, --u32
    data: buffer, --u8[]
}

local function tonum(num)
    return tonumber(num,2)
end

function Layer3.encode(packet: Packet): buffer
    local offset = 0
    local obuf = buffer.create(buffer.len(packet.data)+16)
    buffer.writeu8(obuf,offset,tonum("00000100")); offset += 1
    buffer.writeu8(obuf,offset,0); offset += 1
    buffer.writeu16(obuf,offset,buffer.len(obuf)); offset += 2
    buffer.writeu8(obuf,offset,packet.ttl); offset += 1
    local chckPos = offset
    buffer.writeu8(obuf,offset,packet.prot); offset += 5
    buffer.writeu32(obuf,offset,packet.src); offset += 4
    buffer.writeu32(obuf,offset,packet.dst); offset += 4
    buffer.writeu32(obuf,chckPos,hash32(obuf))
    buffer.copy(obuf, offset, packet.data)
    return obuf
end
-- ok
return Layer3 -- bie haha push this to github when you go