-- Bounded, per-Spotify-artist records. Only explicitly verified aliases are used.
local M={};local Store={};Store.__index=Store
local function valid(id)return type(id)=='string' and #id<=64 and id:match('^[%w]+$')~=nil end
function M.new(o) assert(o and o.storage and o.json and o.dir);return setmetatable(o,Store) end
function Store:path(id)if valid(id) then return self.dir..'/'..id..'.json' end end
function Store:load(id)
 local p=self:path(id);if not p then return nil end;local raw=self.storage:read(p,65536);if not raw then return nil end
 local ok,v=pcall(self.json.decode,raw);if not ok or type(v)~='table' or v.version~=1 or v.id~=id or type(v.aliases)~='table' or #v.aliases>32 then return nil end
 local aliases={};for _,a in ipairs(v.aliases)do if type(a)=='string' and #a>0 and #a<=200 then aliases[#aliases+1]=a end end;v.aliases=aliases;return v
end
function Store:save(id,patch)
 local p=self:path(id);if not p or type(patch)~='table' then return false end
 local v=self:load(id) or {version=1,id=id,aliases={}};for _,k in ipairs({'name','bio','bio_source','checked_at','image_url','netease_id'})do if patch[k]~=nil then v[k]=patch[k] end end
 local ok,data=pcall(self.json.encode,v);if not ok or #data>65536 or not self.storage:mkdir_p(self.dir) then return false end;return self.storage:write_atomic(p,data)
end
function Store:display_name(id,original)
 local v=self:load(id);if v then for _,name in ipairs(v.aliases)do if name:find('[\228-\233]') then return require('soundring.lyrics_online').simplified(name) end end end;return original
end
function Store:image_path(id)if valid(id) then return self.dir..'/'..id..'.gray' end end
function Store:save_alias(id,original,alias)
 local p=self:path(id);if not p or type(alias)~='string' or #alias==0 or #alias>200 then return false end
 local v=self:load(id) or {version=1,id=id,aliases={}};v.name=type(original)=='string' and original:sub(1,200) or v.name
 for _,a in ipairs(v.aliases)do if a==alias then return true end end;if #v.aliases>=32 then return false end
 v.aliases[#v.aliases+1]=alias;local ok,data=pcall(self.json.encode,v);if not ok or #data>65536 or not self.storage:mkdir_p(self.dir) then return false end
 return self.storage:write_atomic(p,data)
end
return M
