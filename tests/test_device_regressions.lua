local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local json=require('core.json');local requests={};local sp=require('soundring.spotify').new({http={request=function(_,o,cb)requests[#requests+1]=o;cb({ok=true,status=204,body=''})end},json=json,client_id='c',token={access_token='x'},save_token=function()return true end})
for _,action in ipairs({'play','pause','previous','next'}) do sp:control(action,function(r)assert(r.ok)end);local o=requests[#requests];assert(o.headers['Content-Length']=='0' and o.body==nil) end
sp:play_uri('spotify:track:abc',function(r)assert(r.ok)end);assert(requests[#requests].body and not requests[#requests].headers['Content-Length'])
local online=require('soundring.lyrics_online');online.fetch=function(o,t,cb)cb({status='not_found'})end
local callbacks,reads={},{};local now=0;local player={}
function player:play_uri(uri,cb)callbacks[#callbacks+1]={uri=uri,cb=cb}end
function player:playback(cb)reads[#reads+1]=cb end
function player:liked(id,cb)cb({ok=true,data={false}})end
local a=require('soundring.app').new({spotify=player,http={},json=json,load_choice=function()end,save_choice=function()return true end,now=function()return now end})
a:action('play_uri','spotify:track:first');a:action('play_uri','spotify:track:second');assert(#callbacks==1);callbacks[1].cb({ok=true});assert(#callbacks==2 and callbacks[2].uri=='spotify:track:second');callbacks[2].cb({ok=true});assert(#reads==1)
local function result(id)return {ok=true,data={item={id=id,name=id,artists={},album={}},device={}}}end
reads[1](result('first'));assert(not a.state.track and a.reconcile_at==2);now=2;a:refresh();reads[2](result('second'));assert(a.state.track.id=='second')
a:refresh();a:refresh();assert(#reads==3);reads[3](result('first'));assert(#reads==4);reads[4](result('second'));assert(a.state.track.id=='second')
print('Device regressions: zero length, serial playlist selection, stale playback and coalescing passed')

sp:play_uri('spotify:track:abc',function(r)assert(r.ok)end,'spotify:playlist:xyz');local body=json.decode(requests[#requests].body);assert(body.context_uri=='spotify:playlist:xyz' and body.offset.uri=='spotify:track:abc' and body.position_ms==0 and not body.uris)
sp:play_uri('spotify:track:abc',function(r)assert(r.ok)end,'spotify:album:bad/../../');body=json.decode(requests[#requests].body);assert(body.uris[1]=='spotify:track:abc' and not body.context_uri)
print('Context playback: playlist offset targets requested track; invalid context rejected')

local pending_reads={};local clock=0;local fake={play_uri=function(_,uri,cb)cb({ok=true,status=204})end,playback=function(_,cb)pending_reads[#pending_reads+1]=cb end,liked=function(_,id,cb)cb({ok=true,data={false}})end}
local test=require('soundring.app').new({spotify=fake,http={},json=json,load_choice=function()end,save_choice=function()return true end,now=function()return clock end});test:action('play_uri',{uri='spotify:track:target',context='spotify:album:album'});clock=11;pending_reads[1]({ok=true,data={item={id='old',name='Old',artists={},album={}}}});assert(test.state.status=='play_not_confirmed' and test.state.track.id=='old')
print('Playback: unconfirmed 204 reports failure and displays actual observed track')
