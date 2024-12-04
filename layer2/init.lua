local layer1 = require('../layer1')
local Layer2 = {}

Layer2.MTU = layer1.MTU - 12

type Packet = {
    src: number, -- u48 (6 bytes)
    dst: number, -- u48
    data: buffer
}

return Layer2