local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local json=require('core.json');local events={};local file={};local http={request=function(_,o,cb)
 if o.url:find('musicu.fcg',1,true) then cb({ok=true,body=json.encode({req_1={data={body={song={list={{name='Different Mix',mid='abc01',interval=180,singer={{name='Singer'}},album={name='Album'}}}}}}}})})
 elseif o.url:find('fcg_query_lyric',1,true) then cb({ok=true,body=json.encode({lyric='WzAwOjAxLjAwXSBIZWxsbw=='})})
 else cb({ok=false,status=503}) end
end}
local sp={playback=function(_,cb)cb({ok=true,data={item={id='spotify1',name='Song',artists={{name='Singer'}},duration_ms=180000,album={name='Album'}},is_playing=true}})end,liked=function(_,id,cb)cb({ok=true,data={false}})end}
local app=require('soundring.app').new({spotify=sp,http=http,json=json,load_choice=function(id)return file[id] end,save_choice=function(id,v)file[id]=v;return true end,changed=function(s)events[#events+1]=s.page end})
app:refresh();assert(app.state.lyrics.status=='not_found');app:action('lyrics_search','qq');assert(app.state.page=='lyrics_search' and #app.state.lyrics.candidates==1)
app:action('lyrics_choose',1);assert(app.state.page=='now' and app.state.lyrics_visible and app.state.lyric_lines[1].text=='Hello' and file.spotify1.id=='abc01')
local app2=require('soundring.app').new({spotify=sp,http=http,json=json,load_choice=function(id)return file[id] end,save_choice=function()return true end});app2:refresh();assert(app2.state.lyrics.remembered and app2.state.lyric_lines[1].text=='Hello')
print('Full lyric workflow: unmatched automatic -> manual search -> select -> show -> restore passed')
