local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local json=require('core.json');local sp=require('soundring.spotify');local requests={};local queue={};local saved
local h={request=function(_,opts,cb)requests[#requests+1]=opts;local next=table.remove(queue,1);assert(next);cb(next)end}
local now=1
local c=sp.new({http=h,json=json,client_id='client',token={access_token='old',refresh_token='refresh',expires_at_ms=1000000},now=function()return now end,save_token=function(t)saved=t;return true end})
queue={{ok=false,status=401},{ok=true,status=200,body='{"access_token":"new","expires_in":3600}'},{ok=true,status=200,body='{"is_playing":true}'}}
local out;c:playback(function(r)out=r end);assert(out.ok and out.data.is_playing and saved.access_token=='new' and saved.refresh_token=='refresh');assert(#requests==3)
queue={{ok=false,status=401}};requests={};c:control('next',function(r)out=r end);assert(not out.ok and #requests==1)
queue={{ok=false,status=429}};requests={};c:control('pause',function(r)out=r end);assert(out.error=='rate_limited' and #requests==1)
requests={};c:playback(function(r)out=r end);assert(out.error=='rate_limited' and #requests==0)
now=62
requests={};c:seek(-1,function(r)out=r end);assert(out.error=='invalid_position' and #requests==0)
print('Spotify client: token refresh, read retry, no control retry, rate-limit and invalid input passed')
requests={};queue={{ok=true,status=200,body='[true]'}};c:liked('abc123',function(r)out=r end);assert(out.ok and out.data[1] and requests[1].url:find('library/contains',1,true))
requests={};queue={{ok=true,status=200,body=''}};c:set_liked('abc123',true,function(r)out=r end);assert(out.ok and requests[1].method=='PUT' and requests[1].url:find('spotify%%3Atrack%%3Aabc123'))
requests={};c:play_uri('https://example.com',function(r)out=r end);assert(out.error=='invalid_track' and #requests==0)
print('Spotify library URI, like and track URI validation passed')
local callbacks={};local refresh_count=0;local sent={}
local async={request=function(_,o,cb)if o.url:find('accounts.spotify.com',1,true)then refresh_count=refresh_count+1;callbacks.refresh=cb else sent[#sent+1]=o;cb({ok=true,status=200,body='{}'})end end}
local once=sp.new({http=async,json=json,client_id='c',token={access_token='old',refresh_token='r',expires_at_ms=0},now=function()return 100 end,save_token=function()return true end})
local completed=0;once:playback(function(r)assert(r.ok);completed=completed+1 end);once:devices(function(r)assert(r.ok);completed=completed+1 end);assert(refresh_count==1 and #sent==0)
callbacks.refresh({ok=true,status=200,body='{"access_token":"new","expires_in":3600}'});assert(completed==2 and #sent==2)
print('Spotify concurrent token refresh coalescing passed')
