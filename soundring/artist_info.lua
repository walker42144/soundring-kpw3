-- Fetch one artist at a time; user-visible first, stale responses discarded.
local M={};local Session={};Session.__index=Session
local function enc(s)return (tostring(s):gsub('([^%w%-%.%_%~])',function(c)return string.format('%%%02X',c:byte())end))end
function M.new(o)assert(o.spotify and o.http and o.json and o.store and o.covers and o.storage and o.changed);return setmetatable({o=o,generation=0,items={}},Session)end
function Session:update()self.o.changed(self.items,self.index)end
function Session:set_track(artists,force)
 self.generation=self.generation+1;local gen=self.generation;if self.o.http.cancel_group then self.o.http:cancel_group('artist-bio-'..tostring(self)) end;self.o.covers:clear();self.items={};self.index=1
 for _,a in ipairs(artists or {}) do if type(a.id)=='string' and a.id:match('^[%w]+$') and #a.id<=64 then local cached=self.o.store:load(a.id);local path=self.o.store:image_path(a.id);self.items[#self.items+1]={id=a.id,name=a.name or '',display_name=self.o.store.display_name and self.o.store:display_name(a.id,a.name or '') or a.name or '',netease_id=cached and cached.netease_id,bio=cached and cached.bio,image_path=self.o.storage:exists(path) and path or nil,cached=not force and cached and ((type(cached.bio)=='string' and cached.bio~='' and self.o.storage:exists(path)) or (type(cached.checked_at)=='number' and os.time()>=cached.checked_at and os.time()-cached.checked_at<21600))} end end
 self:update();self:load_next(gen,1)
end
function Session:refresh()
 local input={};for _,a in ipairs(self.items) do input[#input+1]={id=a.id,name=a.name} end;local index=self.index or 1;self:set_track(input,true);self.index=math.min(index,math.max(1,#self.items));self:update()
end
function Session:select(step)if #self.items==0 then return end;self.index=(self.index-1+step)%#self.items+1;self:update()end
-- A NetEase portrait is used only when the artist ID was previously verified.
function Session:domestic_image(gen,a,done)
 local id=a.netease_id;if type(id)~='string' or not id:match('^%d+$') or #id>20 then done();return end
 local o=self.o;o.http:request({url='https://music.163.com/api/artist/'..id,headers={Referer='https://music.163.com/'},timeout=8,max_bytes=524288,group='artist-bio-'..tostring(self)},function(r)
  if gen~=self.generation then return end;local ok,d=pcall(o.json.decode,r and r.body or '');local artist=ok and type(d)=='table' and d.artist;local url=artist and artist.img1v1Url
  if not r or not r.ok or not artist or tostring(artist.id)~=id or type(url)~='string' or not url:match('^https://p[1-4]%.music%.126%.net/[%w_%%=%-]+/%d+%.jpg$') then done();return end
  o.covers:fetch(url,function(path)
   if gen~=self.generation then return end
   if path then local raw=o.storage:read(path,360001);local dst=o.store:image_path(a.id);if raw and #raw==360000 and o.storage:mkdir_p(o.store.dir) and o.storage:write_atomic(dst,raw) then a.image_path=dst;self:update() end end
   done()
  end)
 end)
end
-- Only accept the biography when Wikidata explicitly confirms the Spotify ID.
function Session:domestic_bio(gen,a,done)
 local id=a.netease_id;if type(id)~='string' or not id:match('^%d+$') or #id>20 then done(false);return end
 local o=self.o;o.http:request({url='https://music.163.com/api/artist/introduction?id='..id,headers={Referer='https://music.163.com/'},timeout=8,max_bytes=524288,group='artist-bio-'..tostring(self)},function(r)
  if gen~=self.generation then return end;local ok,d=pcall(o.json.decode,r and r.body or '');local value=ok and type(d)=='table' and d.briefDesc
  if type(value)=='string' and value~='' then a.bio=value:gsub('[\r\n]+',' ');a.bio=a.bio:match('^(.-。)') or a.bio;a.bio_source='netease';done(true) else done(false) end
 end)
end
function Session:bio(gen,a,done)
 if self.foreign_retry_after and os.time()<self.foreign_retry_after then done();return end
 local o=self.o;local function get(url,cb)
  o.http:request({url=url,method='GET',timeout=12,max_bytes=524288,group='artist-bio-'..tostring(self)},function(r)
   if gen~=self.generation then return end;local ok,v=pcall(o.json.decode,r and r.body or '');if not r or not r.ok or not ok or type(v)~='table' then self.foreign_retry_after=os.time()+1800;cb(nil) else cb(v) end
  end)
 end
 local q='artist:"'..a.name:gsub('["\\]','')..'"'
 get('https://musicbrainz.org/ws/2/artist/?fmt=json&limit=5&query='..enc(q),function(data)
  local found;for _,v in ipairs(data and data.artists or {})do if type(v.name)=='string' and v.name:lower()==a.name:lower() and (tonumber(v.score) or 0)>=99 then if found then done();return end;found=v end end
  if not found or not found.id or not found.id:match('^[%x%-]+$') then done();return end
  get('https://musicbrainz.org/ws/2/artist/'..found.id..'?inc=url-rels&fmt=json',function(detail)
   local qid;for _,rel in ipairs(detail and detail.relations or {})do if rel.type=='wikidata' and rel.url and rel.url.resource then qid=rel.url.resource:match('^https://www%.wikidata%.org/wiki/(Q%d+)$') end end
   if not qid then done();return end
   get('https://www.wikidata.org/wiki/Special:EntityData/'..qid..'.json',function(wd)
    local e=wd and wd.entities and wd.entities[qid];local match=false
    for _,claim in ipairs(e and e.claims and e.claims.P1902 or {})do local dv=claim.mainsnak and claim.mainsnak.datavalue;if dv and dv.value==a.id then match=true end end
    local title=e and e.sitelinks and e.sitelinks.zhwiki and e.sitelinks.zhwiki.title
    if not match then done();return end
    local labels=e.labels or {};for _,lang in ipairs({'zh-hans','zh-hant','zh'}) do local label=labels[lang] and labels[lang].value;if type(label)=='string' and label~='' then o.store:save_alias(a.id,a.name,label) end end
    local netid;local conflict=false
    for _,claim in ipairs(e.claims and e.claims.P10445 or {})do local dv=claim.mainsnak and claim.mainsnak.datavalue;local v=dv and dv.value;if type(v)=='string' and v:match('^%d+$') and #v<=20 then if netid and netid~=v then conflict=true end;netid=v end end
    local function wiki_fallback()
     if type(title)~='string' or #title>300 then done();return end
     get('https://zh.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&format=json&formatversion=2&titles='..enc(title),function(wiki)
      local page=wiki and wiki.query and wiki.query.pages and wiki.query.pages[1];local bio=page and page.extract
      if type(bio)=='string' and #bio>0 then bio=bio:gsub('[\r\n]+',' ');a.bio=bio:match('^(.-。)') or bio;a.bio_source='https://zh.wikipedia.org/wiki/'..enc(title) end
      done()
     end)
    end
    if netid and not conflict and (not a.netease_id or a.netease_id==netid) then
     a.netease_id=netid;o.store:save(a.id,{netease_id=netid});self:domestic_bio(gen,a,function(found)if found then done() else wiki_fallback() end end)
    else wiki_fallback() end
   end)
  end)
 end)
end
function Session:load_next(gen,n)
 if gen~=self.generation or n>#self.items then return end;local a=self.items[n];local o=self.o
 local function next_item()if gen==self.generation then self:update();self:load_next(gen,n+1)end end
 local function finish() local function save() if gen~=self.generation then return end;o.store:save(a.id,{name=a.name,bio=a.bio or '',bio_source=a.bio_source or '',checked_at=os.time()});a.cached=true;next_item() end;self:domestic_bio(gen,a,function(found)if found then save() else self:bio(gen,a,save) end end) end
 if a.cached then next_item();return end
 o.spotify:artist(a.id,function(r)
  if gen~=self.generation then return end
  if not r or not r.ok or not r.data then self:domestic_image(gen,a,finish);return end
  local data=r.data;local img=data.images and data.images[#data.images];local url=img and img.url
  if type(url)=='string' and url:match('^https://i%.scdn%.co/image/ab676161[%w]+$') then
   o.covers:fetch(url,function(path)
    if gen~=self.generation then return end
    if path then local raw=o.storage:read(path,360001);local dst=o.store:image_path(a.id);if raw and #raw==360000 and o.storage:mkdir_p(o.store.dir) and o.storage:write_atomic(dst,raw) then a.image_path=dst end end
    self:update();if a.image_path then finish() else self:domestic_image(gen,a,finish) end
   end)
  else if a.image_path then finish() else self:domestic_image(gen,a,finish) end end
 end)
end
return M
