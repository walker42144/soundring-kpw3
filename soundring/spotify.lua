-- Spotify Web API adapter; HTTP, clock, JSON and token persistence are injected.
local M={};local Client={};Client.__index=Client
local function enc(s) return (tostring(s):gsub('([^%w%-%.%_%~])',function(c)return string.format('%%%02X',c:byte())end)) end
local function decoded(json,response)
 if not response or not response.body or response.body=='' then return nil end
 local ok,value=pcall(json.decode,response.body);if ok and type(value)=='table' then return value end
end
function M.new(o)
 assert(o and o.http and o.json and o.client_id and o.token and o.save_token)
 return setmetatable({http=o.http,json=o.json,client_id=o.client_id,token=o.token,save_token=o.save_token,now=o.now or os.time},Client)
end
function Client:refresh(cb)
 if self.refresh_waiters then self.refresh_waiters[#self.refresh_waiters+1]=cb;return end
 if not self.token.refresh_token then cb({ok=false,error='authorization_required'});return end
 self.refresh_waiters={cb}
 local function finish(result)
  local waiters=self.refresh_waiters or {};self.refresh_waiters=nil
  for _,notify in ipairs(waiters) do pcall(notify,result) end
 end
 local body='grant_type=refresh_token&refresh_token='..enc(self.token.refresh_token)..'&client_id='..enc(self.client_id)
 self.http:request({url='https://accounts.spotify.com/api/token',method='POST',body=body,headers={['Content-Type']='application/x-www-form-urlencoded'},timeout=15,max_bytes=65536,priority=true,sensitive_values={self.token.refresh_token,self.client_id}},function(r)
  local d=decoded(self.json,r)
  if r and r.status==429 then local delay=math.max(1,tonumber(r.retry_after) or 60);self.rate_limit_until=self.now()+delay;finish({ok=false,status=429,error='rate_limited',retry_after=delay});return end
  if not r or not r.ok or not d or not d.access_token then local status=r and r.status or 0;local err=r and r.error=='request queue full' and 'queue_full' or status==0 and 'network_error' or (status==400 or status==401 or status==403) and 'token_refresh_failed' or 'request_failed';finish({ok=false,status=status,error=err});return end
  local next_token={};for k,v in pairs(self.token) do next_token[k]=v end
  next_token.access_token=d.access_token;next_token.refresh_token=d.refresh_token or next_token.refresh_token
  next_token.expires_at_ms=(self.now()+tonumber(d.expires_in or 3600)-60)*1000
  local ok=self.save_token(next_token)
  if not ok then finish({ok=false,error='token_save_failed'});return end
  self.token=next_token;finish({ok=true})
 end)
end
function Client:call(method,path,body,cb)
 if self.rate_limit_until and self.now()<self.rate_limit_until then cb({ok=false,status=429,error='rate_limited',retry_after=self.rate_limit_until-self.now()});return end
 assert(path:match('^/v1/'), 'invalid Spotify API path')
 local function send(retried)
  local opts={url='https://api.spotify.com'..path,method=method,headers={Authorization='Bearer '..self.token.access_token},timeout=15,max_bytes=524288,priority=true,sensitive_values={self.token.access_token,self.token.refresh_token}}
  if body then opts.headers['Content-Type']='application/json';opts.body=self.json.encode(body) elseif method=='POST' or method=='PUT' then opts.headers['Content-Length']='0' end
  self.http:request(opts,function(r)
   if r and r.status==401 and not retried and method=='GET' then self:refresh(function(res)if res.ok then send(true) else cb(res) end end);return end
   if r and r.status==429 then local delay=math.max(1,tonumber(r.retry_after) or 60);self.rate_limit_until=self.now()+delay;cb({ok=false,status=429,error='rate_limited',retry_after=delay});return end
   if r and r.ok then cb({ok=true,status=r.status,data=decoded(self.json,r)});return end
   local status=r and r.status or 0;local err=r and r.error=='request queue full' and 'queue_full' or status==401 and 'token_expired' or status==403 and 'device_unavailable' or status==404 and 'device_unavailable' or status==0 and 'network_error' or 'request_failed';cb({ok=false,status=status,error=err})
  end)
 end
 if not self.token.access_token or (self.token.expires_at_ms and self.now()*1000>=self.token.expires_at_ms) then
  self:refresh(function(res) if res.ok then send(false) else cb(res) end end)
 else send(false) end
end
function Client:playback(cb) self:call('GET','/v1/me/player',nil,cb) end
function Client:queue(cb) self:call('GET','/v1/me/player/queue',nil,cb) end
function Client:artist(id,cb) if type(id)~='string' or not id:match('^[%w]+$') or #id>64 then cb({ok=false,error='invalid_artist'});return end;self:call('GET','/v1/artists/'..id,nil,cb) end
function Client:devices(cb) self:call('GET','/v1/me/player/devices',nil,cb) end
function Client:playlists(offset,cb) if type(offset)=='function' then cb=offset;offset=0 end;offset=math.max(0,math.floor(tonumber(offset) or 0));self:call('GET','/v1/me/playlists?limit=20&offset='..offset,nil,cb) end
function Client:search(term,offset,cb) if type(offset)=='function' then cb=offset;offset=0 end;offset=math.max(0,math.floor(tonumber(offset) or 0));self:call('GET','/v1/search?type=track&limit=10&offset='..offset..'&q='..enc(term),nil,cb) end
function Client:control(action,cb)
 local actions={play={'PUT','/v1/me/player/play'},pause={'PUT','/v1/me/player/pause'},next={'POST','/v1/me/player/next'},previous={'POST','/v1/me/player/previous'}}
 local a=actions[action];if not a then cb({ok=false,error='unknown_action'});return end
 self:call(a[1],a[2],nil,cb)
end
function Client:seek(ms,cb)
 ms=tonumber(ms);if not ms or ms<0 then cb({ok=false,error='invalid_position'});return end
 self:call('PUT','/v1/me/player/seek?position_ms='..math.floor(ms),nil,cb)
end
function Client:transfer(id,cb) if not id or id=='' then cb({ok=false,error='invalid_device'});return end;self:call('PUT','/v1/me/player', {device_ids={id},play=true},cb) end
function Client:volume(value,cb)
 value=tonumber(value);if not value or value<0 or value>100 then cb({ok=false,error='invalid_volume'});return end
 self:call('PUT','/v1/me/player/volume?volume_percent='..math.floor(value),nil,cb)
end
function Client:shuffle(enabled,cb) self:call('PUT','/v1/me/player/shuffle?state='..(enabled and 'true' or 'false'),nil,cb) end
function Client:repeat_mode(mode,cb)
 if mode~='off' and mode~='track' and mode~='context' then cb({ok=false,error='invalid_repeat'});return end
 self:call('PUT','/v1/me/player/repeat?state='..mode,nil,cb)
end
local function track_uri(id)
 if type(id)~='string' or not id:match('^[%w]+$') or #id>64 then return nil end
 return 'spotify:track:'..id
end
function Client:liked(id,cb)
 local uri=track_uri(id);if not uri then cb({ok=false,error='invalid_track'});return end
 self:call('GET','/v1/me/library/contains?uris='..enc(uri),nil,cb)
end
function Client:set_liked(id,enabled,cb)
 local uri=track_uri(id);if not uri then cb({ok=false,error='invalid_track'});return end
 self:call(enabled and 'PUT' or 'DELETE','/v1/me/library?uris='..enc(uri),nil,cb)
end
function Client:playlist_items(id,offset,cb)
 if type(id)~='string' or not id:match('^[%w]+$') or #id>64 then cb({ok=false,error='invalid_playlist'});return end
 offset=math.max(0,math.floor(tonumber(offset) or 0));self:call('GET','/v1/playlists/'..id..'/items?limit=20&offset='..offset,nil,cb)
end
function Client:play_uri(uri,cb,context)
 if type(uri)~='string' or not uri:match('^spotify:track:[%w]+$') or #uri>100 then cb({ok=false,error='invalid_track'});return end
 local body={uris={uri}}
 if type(context)=='string' and #context<=100 and (context:match('^spotify:playlist:[%w]+$') or context:match('^spotify:album:[%w]+$')) then body={context_uri=context,offset={uri=uri},position_ms=0} end
 self:call('PUT','/v1/me/player/play',body,cb)
end
return M
