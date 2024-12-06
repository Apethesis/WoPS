local a a={cache={}, load=function(b)if not a.cache[b]then a.cache[b]={c=a[b]()}end return a.cache[b].c end}do function a.a()local b={}
b.__index=b

function b.new()
local c=setmetatable({
_connections={}
},b)

return c
end

function b.Connect(self,c)
table.insert(self._connections,c)

local d=false

return function()
if d then
return
end

table.remove(self._connections,table.find(self._connections,c))
end
end

function b.Wait(self)
local c,

d=(coroutine.running())
d=self:Connect(function(...)
d()
coroutine.resume(c,...)
end)

return coroutine.yield()
end

function b.Fire(self,...)
for c,d in self._connections do
task.spawn(d,...)
end
end

return b end function a.b()
local b,

c=a.load'a',{}
c.__index=c

function c.new(d:Port?)
if not d then
error"startPort cannot be nil"
end
local e=setmetatable({},c)
e.MTU=65536
e.ListenEVENT=b.new()
e.blacklistPorts={}
e.startPort=d
e.newMicros={}
e:updateMicroList()
e:startListening()
return e
end

function c.addBlacklistPort(self,d:Port)
self.blacklistPorts[d]=true
end

function c.removeBlacklistPort(self,d:Port)
self.blacklistPorts[d]=nil
end

local function mergeTable(d:{[any]:any},e:{[any]:any})
for f,g in pairs(e)do
d[f]=g
end
end

function c.send(self,d:buffer)
if buffer.len(d)>self.MTU then
error"Buffer exceeds Layer1 MTU"
end
for e,f in pairs(self.newMicros)do
f:Send(d)
end
end

function c.indexMicro(self)
local d,
e,
f={},{self.startPort},{}
local function markSeen(g:Port?)
f[g]=true
end
local function portSeen(g:Port?):boolean
return f[g]
end
markSeen(self.startPort)
while#e>0 do
local g=table.remove(e)
if not self.blacklistPorts[g]then
local h=GetPartsFromPort(g,"Microcontroller")
table.find(h,Microcontroller)
mergeTable(d,h)
local i=GetPartsFromPort(g,"Port")
for j,k in pairs(i)do
if not portSeen(k)then
markSeen(k)
table.insert(e,k)
end
end
end
end
return d
end

function c.updateMicroList(self)
self.newMicros=self:indexMicro()
end

function c.startListening(self)
task.defer(function()
while true do
pcall(function()
self:updateMicroList()
end)
task.wait(1)
end
end)
task.defer(function()
while true do
local d,e:buffer=Microcontroller:Receive()
if typeof(e)=="buffer"then
self.ListenEVENT:Fire(d,e)
end
end
end)
end

return c end function a.c()
local b,


c={},281474976710655
b.max=c

function b.read(d,e)

local f,
g=buffer.readu32(d,e),buffer.readu16(d,e+4)

return f+g*(4294967296)
end


function b.write(d,e,f)

if f<0 or f>c then
error("Value out of range for u48: "..tostring(f))
end


local g,
h=f%(4294967296),math.floor(f/(4294967296))

buffer.writeu32(d,e,g)
buffer.writeu16(d,e+4,h)
end


function b.tohex(d)
if d<0 or d>c then
error("Value out of range for u48: "..tostring(d))
end
return string.format("%012x",d)
end


function b.fromhex(d)
if#d~=12 then
error"Invalid hex string length for u48"
end
local e=tonumber(d,16)
if not e or e>c then
error"Invalid hex value for u48"
end
return e
end

return b end function a.d()
local b={}
b.__index=b

local c,
d=a.load'c',a.load'a'

local function generateRandomMAC()

local e,
f,
g,
h,
i,
j=math.random(0,255),math.random(0,255),math.random(0,255),math.random(0,255),math.random(0,255),math.random(0,255)
e=bit32.band(e,0xFE)
e=bit32.bor(e,0x02)

return bit32.bor(
bit32.lshift(e,40),
bit32.lshift(f,32),
bit32.lshift(g,24),
bit32.lshift(h,16),
bit32.lshift(i,8),
j
)
end


b.BROADCAST=c.max

function b.new(e)
local f=setmetatable({},b)
f.layer1=e
f.MTU=f.layer1.MTU-12
f.ListenEVENT=d.new()
f.MAC=generateRandomMAC()


f.layer1.ListenEVENT:Connect(function(g,h)
local i,j=pcall(function()return f:decode(h)end)
if i and f:isValidPacket(j)then
f.ListenEVENT:Fire(g,j)
end
end)
return f
end

function b.setMAC(self,e)
if type(e)~="number"or e<0 or e>c.max then
error"Invalid MAC address"
end
self.MAC=e
end

function b.encode(self,e)
local f,
g=0,buffer.create(buffer.len(e.data)+12)

c.write(g,f,e.src)
f=f+6

c.write(g,f,e.dst)
f=f+6

buffer.copy(g,f,e.data)

return g
end

function b.decode(self,e)
if buffer.len(e)<12 then
error"Buffer too small for Layer2 packet"
end

local f=0

local g=c.read(e,f)
f=f+6

local h=c.read(e,f)
f=f+6

local i=buffer.len(e)-f
local j=buffer.create(i)
buffer.copy(j,0,e,f,i)

return{
src=g,
dst=h,
data=j
}
end

function b.send(self,e)
if not self.MAC then
error"Layer2 MAC address not set"
end

if e.src~=self.MAC then
error"Invalid source MAC address"
end

if not self:isValidPacket(e)then
error"Invalid Layer2 packet"
end

local f=self:encode(e)
self.layer1:send(f)
end

function b.isValidPacket(self,e)
if not e or type(e)~="table"then return false end
if type(e.src)~="number"or e.src<0 or e.src>c.max then return false end
if type(e.dst)~="number"or e.dst<0 or e.dst>c.max then return false end
if not e.data or buffer.len(e.data)>self.MTU then return false end
return true
end

return b end end


local b,
c,

d,
e,


f=a.load'b',a.load'd',GetPort(1),GetPartsFromPort(1,"Port"),{}
for g,h in e do
if h~=d then
local i=b.new(h)
i:addBlacklistPort(d)
local j=c.new(i)
f[h]=j
end
end
local g={}


local function forwardPacket(h,i)
local j,
k,
l=i.src,i.dst,os.time()

g[j]={layer2=h,timestamp=l}


for m,n in pairs(g)do
if l-n.timestamp>10 then
g[m]=nil
end
end

local m=g[k]
if m and m.layer2~=h then
m.layer2:send(i)
else
for n,o in pairs(f)do
if o~=h then
o:send(i)
end
end
end
end


for h,i in pairs(f)do
i.ListenEVENT:Connect(function(j,k)
forwardPacket(i,k)
end)
end