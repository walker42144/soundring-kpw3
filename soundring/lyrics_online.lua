-- QQ / NetEase provider client. Protocol inspired by Lyricify Lyrics Helper
-- (Apache-2.0, https://github.com/WXRIW/Lyricify-Lyrics-Helper).
-- All transport is injected and must verify TLS. Responses are bounded by transport.
local M={}
local function encode(s) return (tostring(s):gsub('([^%w%-%.%_%~])',function(c)return string.format('%%%02X',c:byte())end)) end
local function query(t)
 local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys)
 local parts={};for _,k in ipairs(keys) do parts[#parts+1]=encode(k)..'='..encode(t[k]) end
 return table.concat(parts,'&')
end
-- OpenCC character data; retain originals if the data file is unavailable.
local charmap
local function simplified(text)
 if not charmap then
  charmap={};local source=debug.getinfo(1,'S').source:sub(2);local root=source:match('^(.*)[/\\]soundring[/\\]')
  local f=root and io.open(root..'/assets/TSCharacters.txt','rb')
  if f then for line in f:lines() do local a,b=line:match('^(%S+)%s+(%S+)');if a and b then charmap[a]=b end end;f:close() end
 end
 return (tostring(text or ''):gsub('[%z\1-\127\194-\244][\128-\191]*',function(c)return charmap[c] or c end))
end
local function base_title(value)
 local t=tostring(value or ''):gsub('（','('):gsub('）',')')
 t=t:gsub('%s*%-%s*%d%d%d%d%s+[Rr]emaster%w*%s*$',''):gsub('%s*%-%s*[Rr]emaster%w*%s*$','')
 t=t:gsub('%s*%b()',function(group) if group:find('電影',1,true) or group:find('电影',1,true) or group:find('主题曲',1,true) or group:find('主題曲',1,true) then return '' end;return ' '..group end)
 return (t:match('^%s*(.-)%s*$') or t)
end
local function queries(track)
 local raw=track.name..' '..(track.artist or '');local vals={}
 for _,alias in ipairs(track.artist_aliases or {}) do if type(alias)=='string' and alias~='' then local term=track.name..' '..alias;vals[#vals+1]=term;local simple_alias=simplified(term);if simple_alias~=term then vals[#vals+1]=simple_alias end end end
 vals[#vals+1]=raw;local simple=simplified(raw)
 if simple~=raw then vals[#vals+1]=simple end
 local base=base_title(track.name);if base~=track.name then vals[#vals+1]=base..' '..(track.artist or '') end
 if track.artist and track.artist~='' then vals[#vals+1]=track.name end
 if base~=track.name then vals[#vals+1]=base end
 local out,seen={},{};for _,v in ipairs(vals) do if not seen[v] and v~='' then out[#out+1]=v;seen[v]=true end end;return out
end
-- Normalize case, ordinary spacing and equivalent punctuation only. Version words
-- remain part of the title so live/remix/cover versions are never silently merged.
local function normalize(value)
 local s=simplified(value):lower()
 for _,x in ipairs({'　','，','。','、','：','；','！','？','“','”','‘','’','（','）','【','】','《','》','－','—','·'}) do s=s:gsub(x,'') end
 return (s:gsub('%s+',''):gsub('[%p]',''))
end
-- Bounded Unicode-codepoint edit distance: retain Chinese characters intact.
local function codepoints(s)
 local out={};for c in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do out[#out+1]=c end;return out
end
local function similarity(a,b)
 local x,y=codepoints(a),codepoints(b);local n,m=#x,#y
 if n==0 or m==0 or n>128 or m>128 then return 0 end
 local prev={};for j=0,m do prev[j]=j end
 for i=1,n do
  local row={[0]=i}
  for j=1,m do row[j]=math.min(row[j-1]+1,prev[j]+1,prev[j-1]+(x[i]==y[j] and 0 or 1)) end
  prev=row
 end
 return 1-prev[m]/math.max(n,m)
end
local VERSION_MARKERS={'live','remix','acoustic','instrumental','karaoke','cover','demo','spedup','slowed','现场','混音','翻唱','伴奏','纯音乐','不插电','加速','慢速','清唱'}
local function same_version(a,b)
 for _,marker in ipairs(VERSION_MARKERS) do
  local function has(s) if marker:match('^[a-z]+$') then return s:find('%f[%a]'..marker..'%f[%A]')~=nil end;return s:find(marker,1,true)~=nil end
  if has(a)~=has(b) then return false end
 end
 return true
end
local function score(song,track)
 local name,target=normalize(base_title(song.name)),normalize(base_title(track.name))
 local transformed=normalize(song.name)~=normalize(track.name) and (base_title(song.name)~=song.name or base_title(track.name)~=track.name)
 if name=='' or target=='' or not same_version(simplified(song.name):lower(),simplified(track.name):lower()) then return nil end
 local title_sim=name==target and 1 or similarity(name,target)
 if title_sim<0.90 or (name~=target and math.min(#codepoints(name),#codepoints(target))<8) then return nil end
 local artist=normalize(track.artist);if artist=='' then return nil end
 local found=false
 for _,a in ipairs(song.artists or {}) do local n=normalize(a);if n==artist then found=true;break end;for _,alias in ipairs(track.artist_aliases or {}) do if n==normalize(alias) then found=true;break end end end
 if not found then return nil end
 local actual,wanted=tonumber(song.duration),tonumber(track.duration)
 if not actual or not wanted or actual<=0 or wanted<=0 then return nil end
 local diff=math.abs(actual-wanted)
 local album_match=track.album and song.album and normalize(track.album)~='' and normalize(track.album)==normalize(song.album)
 -- Exact title+artist can tolerate modest metadata drift; approximate titles need
 -- album corroboration or very close timing. A missing duration is never guessed.
 if diff>8 or (transformed and diff>3) or (name~=target and not album_match and diff>2) then return nil end
 local points=title_sim*100-math.min(diff,8)*1.5
 if album_match then points=points+10 end
 return points
end
local function matches(song,track) return score(song,track)~=nil end
local function decode64(data)
 local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
 local lut={};for i=1,#chars do lut[chars:sub(i,i)]=i-1 end
 local n,bits,out=0,0,{}
 for c in tostring(data or ''):gmatch('.') do
  if c=='=' then break elseif lut[c] then
   n=n*64+lut[c];bits=bits+6
   if bits>=8 then bits=bits-8;local div=2^bits;local v=math.floor(n/div);out[#out+1]=string.char(v);n=n-v*div end
  elseif not c:match('%s') then return nil end
 end
 return table.concat(out)
end
local function has_timing(text) return type(text)=='string' and text:match('%[%d+:%d+[%d%.]*%]')~=nil end
local function select_song(songs,track)
 local best,best_score,runner_score=nil,nil,nil
 for _,song in ipairs(songs or {}) do
  local value=score(song,track)
  if value and (not best_score or value>best_score) then
   if best and tostring(song.id)~=tostring(best.id) then runner_score=best_score end
   best,best_score=song,value
  elseif value and best and tostring(song.id)~=tostring(best.id) and (not runner_score or value>runner_score) then runner_score=value end
 end
 if best_score and runner_score and best_score-runner_score<2 then return nil,'ambiguous' end
 return best
end
local function json_result(json,response)
 if not response or not response.ok then return nil end
 local ok,data=pcall(json.decode,response.body or '');if ok and type(data)=='table' then return data end
end
local HEADERS_QQ={['Referer']='https://y.qq.com/'}
local HEADERS_NETEASE={['Referer']='https://music.163.com/'}
local function valid_id(source,id)
 local v=tostring(id or '')
 if source=='qq' then return #v>0 and #v<=32 and v:match('^[%w]+$')~=nil end
 if source=='netease' then return #v>0 and #v<=20 and v:match('^%d+$')~=nil end
 return false
end
-- Manual search retains all usable results, not only automatic high-confidence matches.
function M.search(opts,source,track,callback)
 assert(opts and opts.http and opts.json and type(callback)=='function')
 if not track or not track.name or track.name=='' then callback({ok=false,error='missing_metadata'});return end
 local artist=track.artist or '';local keyword=track.search_query or (track.name..' '..artist);local request
 if source=='qq' then
  local payload={req_1={method='DoSearchForQQMusicDesktop',module='music.search.SearchCgiService',param={num_per_page=20,page_num=1,query=keyword,search_type=0}}}
  request={url='https://u6.y.qq.com/cgi-bin/musicu.fcg',method='POST',body=opts.json.encode(payload),headers={['Referer']='https://y.qq.com/',['Content-Type']='application/json'},timeout=12,max_bytes=524288}
 elseif source=='netease' then
  request={url='https://music.163.com/api/search/get/web?'..query({s=keyword,type=1,offset=0,total='true',limit=20}),method='GET',headers=HEADERS_NETEASE,timeout=12,max_bytes=524288}
 else callback({ok=false,error='unknown_source'});return end
 opts.http:request(request,function(r)
  local d=json_result(opts.json,r);if not d then callback({ok=false,error='network_or_response'});return end
  local list
  if source=='qq' then list=d.req_1 and d.req_1.data and d.req_1.data.body and d.req_1.data.body.song and d.req_1.data.body.song.list
  else list=d.result and d.result.songs end
  if type(list)~='table' then callback({ok=false,error='unexpected_response'});return end
  local candidates={}
  for _,x in ipairs(list) do
   local names,artist_ids={},{};for _,a in ipairs(source=='qq' and (x.singer or {}) or (x.artists or {})) do if type(a.name)=='string' then names[#names+1]=a.name;artist_ids[#artist_ids+1]=tostring(a.id or '') end end
   local id=source=='qq' and x.mid or x.id
   local duration=source=='qq' and tonumber(x.interval) or ((tonumber(x.duration) or 0)/1000)
   if valid_id(source,id) and type(x.name)=='string' then
    candidates[#candidates+1]={source=source,id=tostring(id),name=x.name,artists=names,artist_ids=artist_ids,duration=duration,album=x.album and x.album.name}
   end
  end
  callback({ok=true,candidates=candidates})
 end)
end
function M.get(opts,candidate,callback)
 assert(opts and opts.http and opts.json and type(callback)=='function')
 if not candidate or not valid_id(candidate.source,candidate.id) then callback({ok=false,error='invalid_candidate'});return end
 local source=candidate.source;local u,headers
 if source=='qq' then
  u='https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?'..query({songmid=candidate.id,format='json',g_tk=5381,inCharset='utf8',outCharset='utf8',platform='yqq',needNewCode=0});headers=HEADERS_QQ
 else u='https://music.163.com/api/song/lyric?'..query({id=candidate.id,lv=-1,kv=-1,tv=-1});headers=HEADERS_NETEASE end
 opts.http:request({url=u,method='GET',headers=headers,timeout=12,max_bytes=524288},function(r)
  local data=json_result(opts.json,r)
  if not data then callback({ok=false,error='network_or_response'});return end
  local l=source=='qq' and decode64(data.lyric) or (data.lrc and data.lrc.lyric)
  local tr=source=='qq' and decode64(data.trans or data.translyric) or (data.tlyric and data.tlyric.lyric)
  if has_timing(l) then callback({ok=true,status='synced',source=source,lrc=l,translation=tr,candidate=candidate})
  else callback({ok=false,error='no_synced_lyrics'}) end
 end)
end
-- Supplement a QQ result only with a separately matched NetEase translation.
function M.translation_fallback(opts,track,callback)
 local terms=queries(track);local i=0;local deadline=(opts.now or os.time)()+20
 local function next_query()
  if opts.is_current and not opts.is_current() then return end
  i=i+1;if i>#terms or i>3 or (opts.now or os.time)()>=deadline then callback(nil);return end
  local t={};for k,v in pairs(track)do t[k]=v end;t.search_query=terms[i]
  M.search(opts,'netease',t,function(r)
   if not r.ok then callback(nil);return end
   local best,why=select_song(r.candidates,track)
   if not best then next_query();return end
   if math.abs((best.duration or 0)-(track.duration or 0))>2 then callback(nil);return end
   M.get(opts,best,function(found) callback(found.ok and has_timing(found.translation) and found.translation or nil) end)
  end)
 end
 next_query()
end
function M.fetch(opts,track,callback)
 assert(opts and opts.http and opts.json and type(callback)=='function')
 if not track or not track.name or not track.artist or not track.duration or track.duration<=0 then callback({status='missing_metadata'});return end
 local function done_local()
  if has_timing(opts.local_lrc) then callback({status='synced',source='local',lrc=opts.local_lrc}) else callback({status='not_found'}) end
 end
 local search_succeeded=false;local remaining=12;local deadline=(opts.now or os.time)()+45
 local function try_source(source,fallback)
  local terms=queries(track);local index=0
  local function next_query()
   if opts.is_current and not opts.is_current() then return end
   if (opts.now or os.time)()>=deadline then done_local();return end
   index=index+1;if index>#terms or index>3 or remaining<=0 then fallback();return end;remaining=remaining-1
   local candidate_track={};for k,v in pairs(track) do candidate_track[k]=v end;candidate_track.search_query=terms[index]
   M.search(opts,source,candidate_track,function(r)
    if not r.ok then fallback();return end
    search_succeeded=true
    local best,why=select_song(r.candidates,track)
    if not best then next_query();return end
    M.get(opts,best,function(result) if opts.is_current and not opts.is_current() then return end;if result.ok then callback(result);if source=='qq' and opts.on_translation and not has_timing(result.translation) then M.translation_fallback(opts,track,opts.on_translation) end else next_query() end end)
   end)
  end
  next_query()
 end
 local function resolve_alias()
  if (opts.is_current and not opts.is_current()) then return end
  if remaining<=0 or (opts.now or os.time)()>=deadline then done_local();return end
  if not search_succeeded or not track.artist:match('[A-Za-z]') then done_local();return end
  local url='https://music.163.com/api/search/get/web?'..query({s=track.artist,type=100,offset=0,total='true',limit=10})
  opts.http:request({url=url,method='GET',headers=HEADERS_NETEASE,timeout=12,max_bytes=524288},function(r)
   local d=json_result(opts.json,r);local artists=d and d.result and d.result.artists or {};local names,seen={},{}
   for _,entry in ipairs(artists) do
    local exact=normalize(entry.name)==normalize(track.artist)
    for _,a in ipairs(entry.alias or {}) do if normalize(a)==normalize(track.artist) then exact=true end end
    if exact and type(entry.name)=='string' and normalize(entry.name)~=normalize(track.artist) and not seen[normalize(entry.name)] then names[#names+1]=entry.name;seen[normalize(entry.name)]=true end
   end
   if #names~=1 then done_local();return end
   local old=track;track={};for k,v in pairs(old)do track[k]=v end;track.artist_aliases=names
   local alias=names[1];local source_track=track;track={};for k,v in pairs(source_track)do track[k]=v end;track.artist=alias;track.artist_aliases={old.artist}
   try_source('qq',function()try_source('netease',done_local)end)
  end)
 end
 try_source('qq',function()try_source('netease',resolve_alias)end)
end
M.base_title=base_title;M.simplified=simplified;M.queries=queries;M.matches=matches;M.select_song=select_song;M.decode64=decode64
return M
