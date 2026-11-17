-- One JSON map, written atomically, contains Spotify track IDs and chosen source IDs only.
local M={};local Store={};Store.__index=Store
function M.new(o) assert(o and o.storage and o.json and o.path);return setmetatable(o,Store) end
function Store:load_all()
 local raw,err=self.storage:read(self.path,262144);if not raw then if err=='file exceeds size limit' or (self.storage.exists and self.storage:exists(self.path)) then return nil,'invalid_choice_store' end;return {} end
 local ok,data=pcall(self.json.decode,raw);if ok and type(data)=='table' then return data end
 return nil,'invalid_choice_store'
end
function Store:load(id)
 if type(id)~='string' or not id:match('^[%w]+$') or #id>64 then return nil end
 local data=self:load_all();if not data then return nil end
 local c=data[id];if type(c)~='table' or (c.source~='qq' and c.source~='netease') then return nil end
 return {source=c.source,id=c.id}
end
function Store:save(id,choice)
 if type(id)~='string' or not id:match('^[%w]+$') or #id>64 then return false,'invalid_track' end
 if type(choice)~='table' or (choice.source~='qq' and choice.source~='netease') or type(choice.id)~='string' or not choice.id:match('^[%w]+$') or #choice.id>32 then return false,'invalid_choice' end
 if choice.source=='netease' and not choice.id:match('^%d+$') then return false,'invalid_choice' end
 local data,err=self:load_all();if not data then return false,err end
 data[id]={source=choice.source,id=choice.id};local encoded=self.json.encode(data)
 if #encoded>262144 then return false,'choice_store_full' end
 local ok,why=self.storage:write_atomic(self.path,encoded);return ok,why
end
return M
