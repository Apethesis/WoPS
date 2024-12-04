local function leftrotate(x, n)
    return bit32.lrotate(x, n)
end

local constants = {
    0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476,
    0xC3D2E1F0, 0x76543210, 0xFEDCBA98, 0x89ABCDEF,
    0x01234567, 0x3C2D1E0F, 0xF0E1D2C3, 0x1F0E0D0C,
    0x0B0A0908, 0x07060504, 0x03020100, 0xFFFFFFFF,
    0xEEEEEEEE, 0xDDDDDDDD, 0xCCCCCCCC, 0xBBBBBBBB,
    0xAAAAAAAA, 0x99999999, 0x88888888, 0x77777777,
    0x66666666, 0x55555555, 0x44444444, 0x33333333,
    0x22222222, 0x11111111, 0x00000000, 0xFFFFFFFF,
}

local function hash32(inputBuffer)
    local inputLen = buffer.len(inputBuffer)
    local h = 0x01234567

    for offset = 0, inputLen - 4, 4 do
        local chunk = buffer.readu32(inputBuffer, offset)
        local k = constants[((offset // 4) % 32) + 1]
        h = bit32.band(
            leftrotate(h, 5) + bit32.bxor(h, chunk) + k,
            0xFFFFFFFF
        )
    end

    if inputLen % 4 ~= 0 then
        local remaining = 0
        for i = inputLen - (inputLen % 4), inputLen - 1 do
            local byte = buffer.readu8(inputBuffer, i)
            remaining = bit32.bor(bit32.lshift(remaining, 8), byte)
        end
        local k = constants[((inputLen // 4) % 32) + 1]
        h = bit32.band(
            leftrotate(h, 5) + bit32.bxor(h, remaining) + k,
            0xFFFFFFFF
        )
    end
    
    return h
end

return hash32