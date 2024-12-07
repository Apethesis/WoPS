local ip_decode = {}
-- as a man made man

function ip_decode.ipToNumber(ip)
    local o1, o2, o3, o4 = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    return (tonumber(o1) * 2^24) + (tonumber(o2) * 2^16) + (tonumber(o3) * 2^8) + tonumber(o4)
end


function ip_decode.numberToIp(num)
    local o1 = math.floor(num / 2^24) % 256
    local o2 = math.floor(num / 2^16) % 256
    local o3 = math.floor(num / 2^8) % 256
    local o4 = num % 256
    return string.format("%d.%d.%d.%d", o1, o2, o3, o4)
end


function ip_decode.generateIpList(subnet)
    local ip, prefix = subnet:match("(%d+%.%d+%.%d+%.%d+)/(%d+)")
    if not ip or not prefix then
        error("Invalid subnet format")
    end

    local baseIp = ip_decode.ipToNumber(ip)
    local mask = 2^(32 - tonumber(prefix)) - 1
    local startIp = baseIp - (baseIp % (mask + 1))
    local endIp = startIp + mask

    local ipList = {}
    for i = startIp, endIp do
        table.insert(ipList, ip_decode.numberToIp(i))
    end

    return ipList
end


function ip_decode.isIpInSubnet(ip, subnet)
    local ipNum = ip_decode.ipToNumber(ip)
    local baseIp, prefix = subnet:match("(%d+%.%d+%.%d+%.%d+)/(%d+)")
    if not baseIp or not prefix then
        error("Invalid subnet format")
    end

    local baseIpNum = ip_decode.ipToNumber(baseIp)
    local mask = 2^(32 - tonumber(prefix)) - 1
    local startIp = baseIpNum - (baseIpNum % (mask + 1))
    local endIp = startIp + mask

    return ipNum >= startIp and ipNum <= endIp
end

return ip_decode