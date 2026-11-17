local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local j=require('core.json');local lyrics=require('soundring.lyrics');local online=require('soundring.lyrics_online')
assert(online.simplified('聽媽媽的話')=='听妈妈的话');assert(online.matches({name='听妈妈的话',artists={'周杰伦'},duration=180},{name='聽媽媽的話',artist='周杰倫',duration=180}))
assert(not online.matches({name='听妈妈的话 Live',artists={'周杰伦'},duration=180},{name='聽媽媽的話',artist='周杰倫',duration=180}))
assert(lyrics.is_chinese(lyrics.parse('[00:01]繁體中文歌詞\n[00:03]我是你的朋友')))
assert(not lyrics.is_chinese(lyrics.parse('[00:01]私は君のことが好きです')))
assert(not lyrics.is_chinese(lyrics.parse('[00:01]너를 사랑해')))
local clock=1;local reply={ok=false,status=0};local http={request=function(_,o,cb)cb(reply)end};local c=require('soundring.spotify').new({http=http,json=j,client_id='x',token={access_token='x',refresh_token='r'},save_token=function()error('must not write')end,now=function()return clock end})
local out;c:refresh(function(v)out=v end);assert(out.error=='network_error');clock=7;reply={ok=false,status=400};c:refresh(function(v)out=v end);assert(out.error=='token_refresh_failed');clock=18;reply={ok=false,status=429,retry_after=12};c:refresh(function(v)out=v end);assert(out.error=='rate_limited' and c.rate_limit_until==30)
local p={devices=function(_,cb)local d={};for i=1,11 do d[i]={name=tostring(i),id=tostring(i)}end;cb({ok=true,data={devices=d}})end};local a=require('soundring.app').new({spotify=p,http={},json=j,load_choice=function()end,save_choice=function()return true end});a:action('devices');a:action('list_next');assert(a.state.list_offset==8);a:action('list_prev');assert(a.state.list_offset==0)
a.state.lyrics={source='local'};a:action('lyrics_keyword');assert(a.state.lyrics_source_query=='qq')
print('Review regressions: refresh errors, multilingual matching and device pagination passed')
local tr={name='別離',artist='歌手',duration=180};local searchcalls=0
local hh={request=function(_,o,cb)if o.url:find('u6.y.qq.com',1,true) then searchcalls=searchcalls+1;local payload=j.decode(o.body);local q=payload.req_1.param.query;if searchcalls==1 then assert(q=='別離 歌手');cb({ok=true,body=j.encode({req_1={data={body={song={list={}}}}}})}) else assert(q=='别离 歌手');cb({ok=true,body=j.encode({req_1={data={body={song={list={{mid='x1',name='别离',singer={{name='歌手'}},interval=180}}}}}}})}) end else cb({ok=true,body=j.encode({lyric='WzAwOjAxLjAwXSB0ZXN0'})}) end end}
local result;online.fetch({http=hh,json=j},tr,function(x)result=x end);assert(searchcalls==2 and result.source=='qq' and result.ok)
print('Traditional query retries simplified form and retains metadata validation')
local target={name='一首歌 (電影主題曲)',artist='Singer Lin',duration=200}
assert(online.matches({name='一首歌',artists={'歌手林'},duration=200},{name=target.name,artist=target.artist,artist_aliases={'歌手林'},duration=200}))
assert(not online.matches({name='一首歌 Live',artists={'歌手林'},duration=200},{name=target.name,artist=target.artist,artist_aliases={'歌手林'},duration=200}))
assert(online.matches({name='Example Song',artists={'Example'},duration=200},{name='Example Song - 2005 Remaster',artist='Example',duration=201}))
assert(not online.matches({name='Example Song',artists={'Example'},duration=220},{name='Example Song - 2005 Remaster',artist='Example',duration=201}))
print('Artist aliases, film annotations, remasters and version guards passed')
local phase=0;local sock={request=function(_,o,cb)
 if o.url:find('type=100',1,true) then phase=1;cb({ok=true,body=j.encode({result={artists={{name='歌手林',alias={'Singer Lin'}}}}})})
 elseif o.url:find('u6.y.qq.com',1,true) then
  if phase==1 then cb({ok=true,body=j.encode({req_1={data={body={song={list={{mid='abc',name='一首歌',singer={{name='歌手林'}},interval=200}}}}}}})}) else cb({ok=true,body=j.encode({req_1={data={body={song={list={}}}}}})}) end
 elseif o.url:find('lyric/fcgi',1,true) then cb({ok=true,body=j.encode({lyric='WzAwOjAxLjAwXSB0ZXN0'})})
 else cb({ok=true,body=j.encode({result={songs={}}})}) end
end}
local resolved;online.fetch({http=sock,json=j},target,function(v)resolved=v end);assert(resolved and resolved.ok and resolved.source=='qq' and phase==1)
print('Cross-language artist resolver and QQ-first fallback passed')
local fallback_track={name='Example song',artist='Example',duration=200};local stage=0
local fallback_http={request=function(_,o,cb)
 if o.url:find('type=1',1,true) then cb({ok=true,body=j.encode({result={songs={{id=42,name='Example song',artists={{name='Example'}},duration=200000}}}})})
 else cb({ok=true,body=j.encode({lrc={lyric='[00:01.00] original'},tlyric={lyric='[00:01.00] 译文'}})}) end
end}
local translated;online.translation_fallback({http=fallback_http,json=j},fallback_track,function(v)translated=v end);assert(translated=='[00:01.00] 译文')
fallback_track.duration=204;translated=false;online.translation_fallback({http=fallback_http,json=j},fallback_track,function(v)translated=v end);assert(translated==nil)
print('Fallback translation is accepted only for closely timed matching track')
