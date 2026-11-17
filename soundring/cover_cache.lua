-- Persistent Spotify album covers, bounded independently of lyrics and portraits.
local M={};local Cache={};Cache.__index=Cache
local SIZE=600*600
local function valid(id)return type(id)=='string' and #id>0 and #id<=128 and id:match('^[%w]+$')~=nil end
function M.new(o) assert(o and o.storage and o.json and o.dir);return setmetatable({o=o,entries={},total=0,seq=0},Cache) end
function Cache:path(id) if valid(id) then return self.o.dir..'/'..id..'.gray' end end
function Cache:init()
 if self.ready~=nil then return self.ready end
 self.ready=false;local s=self.o.storage
 if not s:mkdir_p(self.o.dir) then return false end
 local raw=s:read(self.o.dir..'/index.json',262144);local index={}
 if raw then local ok,v=pcall(self.o.json.decode,raw);if ok and type(v)=='table' and type(v.entries)=='table' then index=v.entries end end
 for _,name in ipairs(s:list_dir(self.o.dir)) do
  local id=name:match('^([%w]+)%.gray$')
  if valid(id) then
   local size=s:file_size(self:path(id));if not size then return false end
   local n=tonumber(index[id]) or 0;if n<0 or n>1e12 then n=0 end
   self.entries[id]={size=size,used=n};self.total=self.total+size;self.seq=math.max(self.seq,n)
  end
 end
 self.ready=true;return true
end
function Cache:index()
 local entries={};for id,e in pairs(self.entries) do entries[id]=e.used end
 local ok,raw=pcall(self.o.json.encode,{version=1,entries=entries});if ok and #raw<=262144 then self.o.storage:write_atomic(self.o.dir..'/index.json',raw) end
end
function Cache:get(id)
 if not valid(id) or not self:init() then return nil end
 local e=self.entries[id];if not e then return nil end
 if self.o.storage:file_size(self:path(id))~=SIZE then return nil end
 self.seq=self.seq+1;e.used=self.seq;self:index();return self:path(id)
end
function Cache:put(id,data,protected)
 if not valid(id) or type(data)~='string' or #data~=SIZE or not self:init() then return nil end
 local s=self.o.storage;local budget=self.o.budget or 256*1024*1024
 local existing=self.entries[id]
 if existing then
  s:remove(self:path(id));if s:exists(self:path(id)) then return nil end
  self.total=self.total-existing.size;self.entries[id]=nil
 end
 while self.total+SIZE>budget do
  local oldest,age
  for key,e in pairs(self.entries) do if key~=protected and (not oldest or e.used<age or (e.used==age and key<oldest)) then oldest,age=key,e.used end end
  if not oldest then self:index();return nil end
  local e=self.entries[oldest];s:remove(self:path(oldest));if s:exists(self:path(oldest)) then self:index();return nil end
  self.total=self.total-e.size;self.entries[oldest]=nil
 end
 if not s:write_atomic(self:path(id),data) then self:index();return nil end
 self.seq=self.seq+1;self.entries[id]={size=SIZE,used=self.seq};self.total=self.total+SIZE;self:index();return self:path(id)
end
return M
