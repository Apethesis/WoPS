local Layer1 = {}
Layer1.MTU = 2^16
local oldMicros = {}
local newMicros = {}
local function mergeTable(t1: {[any]: any}, t2: {[any]: any})
    for k, v in pairs(t2) do
        t1[k] = v
    end
    -- no need to return t1 because it is modified in place
end
local function indexMicro(startPort: Port?): {[number]: Microcontroller}
    if not startPort then
        error("startPort cannot be nil")
    end
    local micros = {}
    local stack = {startPort}
    local seenPorts = {}
    local function markSeen(port: Port?)
        seenPorts[port] = true
    end

    local function portSeen(port: Port?): boolean
        return seenPorts[port]
    end

    markSeen(startPort)

    while #stack > 0 do 
        local currentPort = table.remove(stack)

        local foundmicros = GetPartsFromPort(currentPort, "Microcontroller")
        mergeTable(micros, foundmicros)
        local ports = GetPartsFromPort(currentPort, "Port")
        for _, port in ports do
            if not portSeen(port) then
                markSeen(port)
                table.insert(stack, port)
            end
        end
    end
    return micros
end

local function createHandler()

local function updateMicroList(startPort: Port?)
    if not startPort then
        error("startPort cannot be nil")
    end

    newMicros = indexMicro(startPort)

    for _, micro in pairs(newMicros) do
        local found = false
        for _, existingMicro in pairs(oldMicros) do
            if existingMicro == micro then
                found = true
                break
            end
        end

        if not found then
            print("New microcontroller detected, creating handler:", micro)
            createHandler(micro)
        end
    end

    oldMicros = newMicros
end









return Layer1