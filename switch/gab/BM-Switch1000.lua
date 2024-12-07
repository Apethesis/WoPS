    -- GPLv3 copyright gab®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™

local Layer1 = require('../../layer1')
local Layer2 = require('../../layer2')
local DHCP = require('../../layer3/dchp.lua')
local ip_decode = require('../../utility/ip_decode.lua')

local port1 = GetPort(1)
local connectedPorts = GetPartsFromPort(1, "Port")
local Disk = GetDisk(1)

local layer2Instances = {}
local dhcpInstances = {}
for _, port in connectedPorts do
    if port ~= port1 then
        local layer1Instance = Layer1.new(port)
        layer1Instance:addBlacklistPort(port1) -- ignore port 1 so the requests dont come 4 times or depending on the number of ports
        local layer2Instance = Layer2.new(layer1Instance)
        layer2Instances[port] = layer2Instance

        -- Create DHCP instance for each Layer2 instance
        local dhcpInstance = DHCP.new(layer2Instance)
        dhcpInstances[port] = dhcpInstance
    end
end
local macTable = {} -- { [macAddress] = { layer2 = Layer2Instance, timestamp = number } }
local ipLeaseTable = {} -- { [ipAddress] = { macAddress = number, leaseExpiry = number } }

-- Load IP lease table from Disk
local function loadIpLeaseTable()
    local data = Disk:Read("ipLeaseTable")
    if data then
        ipLeaseTable = textutils.unserialize(data) or {}
    end
end

-- Save IP lease table to Disk
local function saveIpLeaseTable()
    Disk:Write("ipLeaseTable", textutils.serialize(ipLeaseTable))
end

-- Packet forwarding function
local function forwardPacket(receivingLayer2, packet)
    local srcMAC = packet.src
    local dstMAC = packet.dst
    print(srcMAC, dstMAC, buffer.tostring(packet.data))
    local currentTime = os.time()

    macTable[srcMAC] = { layer2 = receivingLayer2, timestamp = currentTime }

    -- Remove stale entries
    for mac, entry in pairs(macTable) do
        if currentTime - entry.timestamp > 10 then
            macTable[mac] = nil
        end
    end

    -- Handle broadcast packets
    if dstMAC == Layer2.BROADCAST then
        print("omg is this real i have detected a broadcast omg im going to suffer and die a painful death")
        for _, layer2 in pairs(layer2Instances) do
            if layer2 ~= receivingLayer2 then
                print("i am sending this insane information on ", _.PortID, " and i am going to die")
                layer2:send(packet)
            end
        end
        return
    end

    -- Determine destination port
    local destEntry = macTable[dstMAC]
    if destEntry and destEntry.layer2 ~= receivingLayer2 then
        -- Forward to the specific port
        destEntry.layer2:send(packet)
    else
        -- Broadcast to all other ports
        for _, layer2 in pairs(layer2Instances) do
            if layer2 ~= receivingLayer2 then
                layer2:send(packet)
            end
        end
    end
end

-- Connect to ListenEVENT of each Layer2 instance
for _, layer2 in pairs(layer2Instances) do
    layer2.ListenEVENT:Connect(function(sender, packet)
        forwardPacket(layer2, layer2:decode(packet))
    end)
end

-- DHCP server functions
local function handleDhcpDiscover(dhcpInstance, clientMAC)
    local availableIp = nil
    for _, ip in ipairs(ip_decode.generateIpList("192.168.1.0/24")) do
        if not ipLeaseTable[ip] or os.time() > ipLeaseTable[ip].leaseExpiry then
            availableIp = ip
            break
        end
    end

    if availableIp then
        local leaseTime = 3600 -- 1 hour lease time
        local leaseExpiry = os.time() + leaseTime
        ipLeaseTable[availableIp] = { macAddress = clientMAC, leaseExpiry = leaseExpiry }
        saveIpLeaseTable()
        dhcpInstance:offer(clientMAC, ip_decode.ipToNumber(availableIp), leaseTime)
    else
        dhcpInstance:nak(clientMAC)
    end
end

local function handleDhcpRequest(dhcpInstance, clientMAC, requestedIp)
    local ipStr = ip_decode.numberToIp(requestedIp)
    if ipLeaseTable[ipStr] and ipLeaseTable[ipStr].macAddress == clientMAC then
        local leaseTime = 3600 -- 1 hour lease time
        local leaseExpiry = os.time() + leaseTime
        ipLeaseTable[ipStr].leaseExpiry = leaseExpiry
        saveIpLeaseTable()
        dhcpInstance:ack(clientMAC, requestedIp, leaseTime)
    else
        dhcpInstance:nak(clientMAC)
    end
end

-- Connect to DHCP events
for _, dhcpInstance in pairs(dhcpInstances) do
    dhcpInstance.EVENT:Connect(function(ip, leaseExpiry)
        print("Assigned IP:", ip_decode.numberToIp(ip), "Lease Expiry:", leaseExpiry)
    end)

    dhcpInstance.layer2.ListenEVENT:Connect(function(sender, packet)
        local msgType, clientMAC, ip, leaseExpiry = dhcpInstance:decodePacket(packet.data)
        if msgType == DHCP.DHCP_DISCOVER then
            handleDhcpDiscover(dhcpInstance, clientMAC)
        elseif msgType == DHCP.DHCP_REQUEST then
            handleDhcpRequest(dhcpInstance, clientMAC, ip)
        end
    end)
end

-- Load IP lease table on startup
loadIpLeaseTable()