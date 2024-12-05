local layer2 = require('../layer2')
local layer3 = require('./init.lua') -- Include Layer3 to access layer3.IP
local signal = require('../utility/signal.lua')
local u48 = require('../utility/u48.lua')
local discover = {}
local cache = {} -- {[ip: number]: {mac: number, timestamp: number}}

local CACHE_TIMEOUT = 5 -- seconds
local TYPE_REQUEST = 1
local TYPE_RESPONSE = 2

local function encodePacket(ptype: number, ip: number, mac: number): buffer
    local buf = buffer.create(13) -- 1 byte type + 4 bytes IP + 8 bytes MAC (6 bytes + padding)
    buffer.writeu8(buf, 0, ptype)
    buffer.writeu32(buf, 1, ip)
    u48.write(buf, 5, mac)
    return buf
end

local function decodePacket(buf: buffer): (number, number, number)
    local ptype = buffer.readu8(buf, 0)
    local ip = buffer.readu32(buf, 1)
    local mac = u48.read(buf, 5)
    return ptype, ip, mac
end

local function updateCache(ip: number, mac: number)
    cache[ip] = {mac = mac, timestamp = os.time()}
end

local function isValidCache(ip: number): boolean
    local entry = cache[ip]
    return entry and (os.time() - entry.timestamp <= CACHE_TIMEOUT)
end

function discover.get(targetIp: number): number?
    if isValidCache(targetIp) then
        return cache[targetIp].mac
    end

    discover.request(targetIp)

    local startTime = os.time()
    while os.time() - startTime < 1 do -- 1 second timeout
        if isValidCache(targetIp) then
            return cache[targetIp].mac
        end
        task.wait()
    end

    return nil
end

function discover.request(targetIp: number)
    local packet = {
        src = layer2.MAC,
        dst = layer2.BROADCAST,
        data = encodePacket(TYPE_REQUEST, targetIp, layer2.MAC)
    }
    layer2.send(packet)
end

-- Listen for ARP packets
layer2.ListenEVENT:Connect(function(sender, packet)
    local success, ptype, ip, mac = pcall(decodePacket, packet.data)
    if not success then return end

    if ptype == TYPE_REQUEST then
        if ip == layer3.IP then -- Use layer3.IP instead of layer2.IP
            -- Someone is asking for our MAC address
            local responsePacket = {
                src = layer2.MAC,
                dst = packet.src, -- Reply directly to the requester
                data = encodePacket(TYPE_RESPONSE, ip, layer2.MAC)
            }
            layer2.send(responsePacket)
        end
    elseif ptype == TYPE_RESPONSE then
        -- Update cache with IP-MAC mapping
        updateCache(ip, mac)
    end
end)

return discover