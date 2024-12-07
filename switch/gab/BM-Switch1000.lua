    -- GPLv3 copyright gab®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®®™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™™

local Layer1 = require('../../layer1')
local Layer2 = require('../../layer2')

local port1 = GetPort(1)
local connectedPorts = GetPartsFromPort(1, "Port")

local layer2Instances = {}
for _, port in connectedPorts do
    if port ~= port1 then
        local layer1Instance = Layer1.new(port)
        layer1Instance:addBlacklistPort(port1) -- ignore port 1 so the requests dont come 4 times or depending on the number of ports
        local layer2Instance = Layer2.new(layer1Instance)
        layer2Instances[port] = layer2Instance
    end
end
local macTable = {} -- { [macAddress] = { layer2 = Layer2Instance, timestamp = number } }

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