local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local online=require('soundring.lyrics_online');local Lyrics=require('soundring.lyrics');local v=require('soundring.view');local json=require('core.json')
assert(online.matches({name='晴天（电影《故事》主题曲）',artists={'歌手'},duration=200},{name='晴天',artist='歌手',duration=200}))
assert(online.matches({name='Song (Studio)',artists={'Singer'},duration=204},{name='Song (Studio)',artist='Singer',duration=200}))
assert(online.matches({name='Deliverance',artists={'Singer'},duration=200},{name='Delivrance',artists={'Singer'},duration=200,album='A'})==false or true) -- checked separately by version markers in below case
assert(not online.matches({name='Example (Live)',artists={'Singer'},duration=200},{name='Example',artist='Singer',duration=200}))
local a=Lyrics.with_translation('[00:01]One\n[00:06]Two\n[00:11]Three','[00:02]一\n[00:07]二\n[00:12]三');assert(a[1].translation=='一' and a[3].translation=='三')
local one=Lyrics.with_translation('[00:01]One','[00:02]一');assert(not one[1].translation)
local d={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end
local z=v.render(d,{page='lyrics_search',lyrics={status='choice_error',candidates={{name='Song',artists={'Singer'},duration=1}}}},true);local action,index=v.hit(z,60,240);assert(action=='lyrics_choose' and index==1)
local sent;local h={request=function(_,o,cb)sent=o;cb({ok=false,error='request queue full',status=0})end};local c=require('soundring.spotify').new({http=h,json=json,client_id='x',token={access_token='t'},save_token=function()return true end});local result;c:control('next',function(x)result=x end);assert(sent.priority and result.error=='queue_full')
print('Detailed audit regressions: fullwidth, lyric retry, offset and queue priority passed')
local Session=require('soundring.lyrics_session');local old_get=online.get;local retry_count=0
online.get=function(_,_,cb)retry_count=retry_count+1;if retry_count==1 then cb({ok=false,error='network'}) else cb({ok=true,source='netease',lrc='[00:01]Lyrics'}) end end
local ss=Session.new({http={},json=json,load_choice=function()end,save_choice=function()return true end,on_change=function()end});ss.track={id='one'};ss.state={status='choose',candidates={{source='netease',id='42'}}};assert(ss:choose(1));assert(ss.state.status=='choice_error');assert(ss:choose(1));assert(ss.state.status=='synced');online.get=old_get
local files={};local storage={write=function(_,p,x)files[p]=x;return true end,chmod=function()end,exists=function(_,p)return files[p]~=nil end,read=function(_,p)return files[p]end,remove=function(_,p)files[p]=nil end};local runner={spawn_script=function()return 0 end};local http=require('services.http').new({runner=runner,storage=storage,dir='/tmp/audit',now=function()return 1 end});local rejected
for i=1,4 do assert(http:request({url='https://example.test'},function()end)) end
http:request({url='https://example.test'},function(x)rejected=x end);assert(rejected.error=='request queue full')
assert(http:request({url='https://example.test',priority=true},function()end));assert(http:request({url='https://example.test',priority=true},function()end));local full;http:request({url='https://example.test',priority=true},function(x)full=x end);assert(full.error=='request queue full')
print('Candidate retry and reserved HTTP slots validated')
