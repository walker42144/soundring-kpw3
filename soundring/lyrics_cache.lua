-- One bounded atomic JSON file per Spotify track; cache can always be removed.
local M={};local Cache={};Cache.__index=Cache
local function valid_id(id)return type(id)=='string' and #id<=64 and id:match('^[%w]+$')~=nil end
function M.new(o)assert(o and o.storage and o.json and o.dir);return setmetatable(o,Cache)end
function Cache:path(id)if valid_id(id) then return self.dir..'/'..id..'.json' end end
function Cache:load(id,choice)
 local p=self:path(id);if not p then return nil end
 local raw=self.storage:read(p,1100000);if not raw then return nil end
 local ok,c=pcall(self.json.decode,raw)
 if not ok or type(c)~='table' or c.version~=1 or c.track_id~=id or type(c.lrc)~='string' or #c.lrc>524288 or not c.lrc:match('%[%d+:%d+[%d%.]*%]') then return nil end
 if c.translation~=nil and (type(c.translation)~='string' or #c.translation>524288) then return nil end
 if c.source~='qq' and c.source~='netease' then return nil end
 if choice then
  if type(c.choice)~='table' or c.choice.source~=choice.source or c.choice.id~=choice.id then return nil end
 elseif c.choice~=nil then return nil end
 return {status='synced',source=c.source,lrc=c.lrc,translation=c.translation,candidates={},cached=true,remembered=choice~=nil,translation_checked_at=type(c.translation_checked_at)=='number' and c.translation_checked_at or nil}
end
function Cache:save(id,result,choice)
 local p=self:path(id);if not p or type(result)~='table' or (result.source~='qq' and result.source~='netease') or type(result.lrc)~='string' or #result.lrc>524288 or not result.lrc:match('%[%d+:%d+[%d%.]*%]') then return false end
 if result.translation~=nil and (type(result.translation)~='string' or #result.translation>524288) then return false end
 local data={version=1,track_id=id,source=result.source,lrc=result.lrc,translation=result.translation,choice=choice,translation_checked_at=result.translation_checked_at}
 local ok,encoded=pcall(self.json.encode,data);if not ok or #encoded>1100000 then return false end
 if not self.storage:mkdir_p(self.dir) then return false end
 if not choice then
  local previous,readerr=self.storage:read(p,1100000)
  if not previous and (readerr=='file exceeds size limit' or (self.storage.exists and self.storage:exists(p))) then return false,'existing_cache_unreadable' end
  if previous then local valid,old=pcall(self.json.decode,previous);if not valid or type(old)~='table' then return false,'existing_cache_invalid' end;if type(old.choice)=='table' then return false,'manual_cache_preserved' end end
 end
 -- Bound growth of automatically fetched cache without deleting existing
 -- entries or preventing explicitly chosen lyrics from being retained.
 if not choice and self.storage.list_dir and self.storage.file_size then
  local total=0;for _,name in ipairs(self.storage:list_dir(self.dir)) do
   if name:match('^[%w]+%.json$') then local size=self.storage:file_size(self.dir..'/'..name);if not size then return false,'cache_size_unavailable' end;total=total+size end
  end
  local old=self.storage:file_size(p) or 0;if total-old+#encoded>(self.auto_budget_bytes or 64*1024*1024) then return false,'cache_full' end
 end
 return self.storage:write_atomic(p,encoded)
end
return M
