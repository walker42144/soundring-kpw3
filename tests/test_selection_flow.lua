local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local view=require('soundring.view');local json=require('core.json');local online=require('soundring.lyrics_online');online.fetch=function(o,t,cb)cb({status='not_found'})end
local sent,contexts={},{};local player={}
function player:play_uri(uri,cb,context)sent[#sent+1]=uri;contexts[#sent]=context;cb({ok=true,status=204})end
function player:playback(cb)cb({ok=true,data={item={id=sent[#sent]:match('([^:]+)$'),name='x',artists={},album={}}}})end
function player:liked(id,cb)cb({ok=true,data={false}})end
function player:playlist_items(id,offset,cb)cb({ok=true,data={items={{item={uri='spotify:track:'..id,name=id}}}}})end
function player:search(term,offset,cb)cb({ok=true,data={tracks={items={{uri='spotify:track:searchresult',name='Search',album={uri='spotify:album:albumid'}}}}}})end
local app=require('soundring.app').new({spotify=player,http={},json=json,load_choice=function()end,save_choice=function()return true end})
local d={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end
local function taprow()local z=assert(view.render(d,app.state));local action,value=view.hit(z,80,200);assert(action=='play_uri' and value);app:action(action,value)end
app:action('playlist_items','first');taprow();app:action('playlist_items','second');taprow();app.state.search_text='sample';app:action('search',0);taprow();assert(sent[1]=='spotify:track:first' and sent[2]=='spotify:track:second' and sent[3]=='spotify:track:searchresult');assert(contexts[1]=='spotify:playlist:first' and contexts[2]=='spotify:playlist:second' and contexts[3]=='spotify:album:albumid');print('Selection flow: playlist A, playlist B and search dispatch distinct track URIs')
