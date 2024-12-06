local l2 = require('../layer2')
local l1 = require("../layer1")
local p1 = GetPort(1)
local thingy = l1.new(p1)
local thingy2 = l2.new(thingy)
local sendstr = "Hello World!"
local test = buffer.create(#sendstr)
local offset = 0
for i=1,#sendstr do
    buffer.writeu8(test,offset,string.sub(sendstr,i,i):byte())
    offset = offset + 1
end
while true do
    thingy2:send({
        src = thingy2.MAC,
        dst = l2.BROADCAST,
        data = test
    })
    task.wait(1)
end