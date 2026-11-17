local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local f={};local storage={write=function(_,p,v)f[p]=v;return true end,chmod=function()end,read=function(_,p)return f[p]end,exists=function(_,p)return f[p]~=nil end,remove=function(_,p)f[p]=nil end}
local runner={spawn_script=function()return 0 end};local client=require('services.http').new({runner=runner,storage=storage,dir='/tmp/test',now=function()return 100 end})
local result;client:request({url='https://api.spotify.com/v1/me/player'},function(r)result=r end)
local prefix='/tmp/test/http-100-1';assert(f[prefix..'.sh']:find('%-%-dump%-header'))
f[prefix..'.status']='429';f[prefix..'.rc']='0';f[prefix..'.out']='';f[prefix..'.headers']='HTTP/1.1 429 Too Many Requests\r\nRetry-After: 37\r\n';f[prefix..'.done']='done';client:poll(true)
assert(result and result.status==429 and result.retry_after==37 and not result.ok);assert(not f[prefix..'.headers'])
print('HTTP: Retry-After capture, 429 handling and temp header cleanup passed')
