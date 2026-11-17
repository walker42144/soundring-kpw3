local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local files={};local pending={};local storage={write=function(_,p,s)files[p]=s;return true end,remove=function(_,p)files[p]=nil end,read=function(_,p)return files[p]end,exists=function(_,p)return files[p]~=nil end,chmod=function()return true end};local calls=0
local runner={spawn_script=function(_,script)calls=calls+1;assert(files[script]);return 0 end,cancel_http_async=function()return true end};local http={request=function(_,o,cb)pending[#pending+1]=cb end}
local c=require('soundring.covers').new({http=http,storage=storage,runner=runner,dir='/owned',converter='/converter'});local result
c:fetch('https://evil.example/x',function(p,e)result=e end);assert(result=='unsupported_cover_url' and #pending==0)
c:fetch('https://i.scdn.co/image/abc123',function(p,e)result=p end);pending[1]({ok=true,body='image'});assert(result=='unsupported_cover_url' and calls==1);files['/owned/cover-2.gray']='gray';files['/owned/cover-2.rc']='0';files['/owned/cover-2.done']='1';c:poll();assert(result=='/owned/cover-2.gray')
c:fetch('https://i.scdn.co/image/abc456',function(p,e)result=p end);pending[2]({ok=true,body='image'});assert(calls==2);c:clear();files['/owned/cover-3.gray']='gray';files['/owned/cover-3.rc']='0';files['/owned/cover-3.done']='1';c:poll();assert(result=='/owned/cover-2.gray' and not files['/owned/cover-2.gray'] and not files['/owned/cover-3.gray'])
print('Async cover handling: allowlist, background completion and stale output cleanup passed')

local before=#pending;c:fetch('https://p2.music.126.net/YSeeLcOZcHKaL42XcpLyPg==/109951170316912578.jpg',function()end);assert(#pending==before+1)
before=#pending;c:fetch('https://p2.music.126.net.evil.example/a/123.jpg',function(p,e)result=e end);assert(#pending==before and result=='unsupported_cover_url')
print('Artist image: verified NetEase CDN is allowed while lookalike hosts are rejected')
