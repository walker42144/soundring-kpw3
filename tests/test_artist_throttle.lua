local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local json=require('core.json');local t=10;local hits={};local pending
local h={request=function(_,o,cb)hits[#hits+1]={url=o.url,t=t};if #hits==1 then cb({ok=true,body=json.encode({artists={{name='Artist',id='1234',score=100}}})})else pending=cb end end}
local store={save_alias=function()end,save=function()end};local s=require('soundring.artist_info').new({spotify={},http=h,json=json,store=store,covers={},storage={},now=function()return t end,changed=function()end});s.generation=1
s:bio(1,{id='abc',name='Artist'},function()end);assert(#hits==1);t=11;s:poll();assert(#hits==1);t=11.1;s:poll();assert(#hits==2 and hits[2].t-hits[1].t>=1.1-1e-8);s.generation=2;pending({ok=false,status=404});assert(not s.foreign_retry_after)
print('Artist metadata: MusicBrainz requests spaced and stale responses ignored')
