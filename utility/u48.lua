local u48 = {}


local MAX_U48 = 2^48 - 1
u48.max = MAX_U48

function u48.read(buf, offset)

    local low = buffer.readu32(buf, offset)
    local high = buffer.readu16(buf, offset + 4)
    
    return low + high * (2^32)
end


function u48.write(buf, offset, value)

    if value < 0 or value > MAX_U48 then
        error("Value out of range for u48: " .. tostring(value))
    end
    

    local low = value % (2^32)
    local high = math.floor(value / (2^32))
    
    buffer.writeu32(buf, offset, low)
    buffer.writeu16(buf, offset + 4, high)
end


function u48.tohex(value)
    if value < 0 or value > MAX_U48 then
        error("Value out of range for u48: " .. tostring(value))
    end
    return string.format("%012x", value)
end


function u48.fromhex(str)
    if #str ~= 12 then
        error("Invalid hex string length for u48") 
    end
    local value = tonumber(str, 16)
    if not value or value > MAX_U48 then
        error("Invalid hex value for u48")
    end
    return value
end

return u48