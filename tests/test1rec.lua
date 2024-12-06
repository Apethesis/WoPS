local l2 = require('../layer2')
local l1 = require("../layer1")
local p1 = GetPort(1)
local thingy = l1.new(p1)
local thingy2 = l2.new(thingy)
local offset = 0
thingy2.ListenEVENT:Connect(function(_, packet)
    local data = thingy2:decode(packet)
    print(data.data)
    local fulstr = ""
    for i=1,buffer.len(data.data) do
        fulstr = fulstr..string.char(buffer.readu8(data.data,offset))
        offset = offset + 1
    end
    offset = 0
    print(fulstr)
end)
