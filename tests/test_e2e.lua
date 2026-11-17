package.path=(arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.')..'/?.lua;'..package.path
local j=require('core.json');local fake={};local saved={};local paths={}
local qq=j.encode({req_1={data={body={song={list={{name='Manually corrected version',mid='qqABC123',interval=180,singer={{name='Singer'}},album={name='Album'}}}}}}}})
local player=j.encode({item={id='spotify123',name='Song',artists={{name='Singer'}},album={name='Album'},duration_ms=180000},progress_ms=1000,is_playing=true,device={name='Speaker'}})
function fake:request(o,cb)
 paths[#paths+1]=o.url
 if o.url:find('/v1/me/player$',1)==nil and o.url:find('musicu.fcg',1,true) then cb({ok=true,status=200,body=qq})
 elseif o.url:find('/v1/me/player$',1) then cb({ok=true,status=200,body=player})
 elseif o.url:find('/v1/me/library/contains',1,true) then cb({ok=true,status=200,body='[false]'})
 elseif o.url:find('fcg_query_lyric',1,true) then cb({ok=true,status=200,body=j.encode({lyric='WzAwOjAxLjAwXSBIZWxsbw=='})})
 else cb({ok=false,status=404}) end
end
local spotify=require('soundring.spotify').new({http=fake,json=j,client_id='c',token={access_token='test',refresh_token='r'},save_token=function()return true end})
local app=require('soundring.app').new({spotify=spotify,http=fake,json=j,load_choice=function(id)return saved[id]end,save_choice=function(id,c)saved[id]=c;return true end})
app:refresh();assert(app.state.track.id=='spotify123');app:action('lyrics');app:action('lyrics_search','qq');assert(app.state.lyrics.status=='choose')
local view=require('soundring.view');local d={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end
local zones=assert(view.render(d,app.state));local action,value=view.hit(zones,50,240);assert(action=='lyrics_choose');app:action(action,value)
assert(app.state.page=='now' and app.state.lyrics_visible and app.state.lyric_lines[1].text=='Hello' and saved.spotify123.id=='qqABC123')
print('End-to-end host: Spotify state -> QQ candidates -> touch -> lyric display and choice save passed')
