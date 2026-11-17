local files={};local saved
local storage={mkdir_p=function()return true end,write_atomic=function(_,p,v)files[p]=v;return true end,write=function(_,p,v)files[p]=v;return true end,read=function(_,p)return files[p]end,exists=function(_,p)return files[p]~=nil end,remove=function(_,p)files[p]=nil end,file_size=function(_,p)return files[p] and #files[p] or nil end,chmod=function()end,list_dir=function(_,p)local out={};for f in pairs(files)do local name=f:match('^'..p..'/([^/]+)$');if name then out[#out+1]=name end end;return out end}
local json={encode=function(v)saved=v;return 'index' end,decode=function()return saved end}
local mod=require('soundring.cover_cache');local opts={storage=storage,json=json,dir='/cache',budget=720000};local data=string.rep('x',360000)
local c=mod.new(opts);assert(c:put('a',data));assert(c:put('b',data));assert(c:get('a'));assert(c:put('c',data));assert(files['/cache/a.gray'] and not files['/cache/b.gray'] and files['/cache/c.gray'])
local restart=mod.new(opts);assert(restart:get('a'));assert(restart:get('c'));assert(not restart:put('../bad',data));assert(not restart:put('d','short'))
files['/cache/a.gray']='bad';assert(not restart:get('a'));assert(restart:put('a',data));assert(#files['/cache/a.gray']==360000)
local callbacks={};local http={request=function(_,o,cb)callbacks[#callbacks+1]=cb end,cancel_group=function()end};local runner={spawn_script=function()return 0 end,cancel_http_async=function()end}
local covers=require('soundring.covers').new({http=http,storage=storage,runner=runner,dir='/tmp',converter='/conv',cache=restart});local path
covers:fetch('https://i.scdn.co/image/a',function(p)path=p end);assert(path=='/cache/a.gray' and #callbacks==0)
covers:clear();assert(files['/cache/a.gray'])
covers:fetch('https://i.scdn.co/image/new',function(p)path=p end);assert(#callbacks==1);callbacks[1]({ok=true,body='image'})
files['/tmp/cover-3.gray']=data;files['/tmp/cover-3.rc']='0';files['/tmp/cover-3.done']='1';covers:poll();assert(path=='/cache/new.gray');covers:clear();assert(files['/cache/new.gray'])
local bad={get=function()error('read failed')end,put=function()error('write failed')end};local fallback=require('soundring.covers').new({http=http,storage=storage,runner=runner,dir='/tmp',converter='/conv',cache=bad});fallback:fetch('https://i.scdn.co/image/fallback',function(p)path=p end);callbacks[#callbacks]({ok=true,body='image'});files['/tmp/cover-1.gray']=data;files['/tmp/cover-1.rc']='0';files['/tmp/cover-1.done']='1';fallback:poll();assert(path=='/tmp/cover-1.gray');fallback:clear();assert(not files['/tmp/cover-1.gray'])
-- A corrupt index is rebuilt from owned files; it does not invalidate covers.
files['/cache/index.json']='corrupt';local brokenjson={encode=json.encode,decode=function()error('corrupt index')end};local rebuilt=mod.new({storage=storage,json=brokenjson,dir='/cache',budget=720000});assert(rebuilt:get('new'))
-- Repeated unique songs remain bounded, and a currently displayed cover is protected.
local stress=mod.new({storage=storage,json=json,dir='/stress',budget=3600000});assert(stress:put('keep',data))
for i=1,200 do assert(stress:put('track'..i,data,'keep'));assert(stress.total<=3600000);assert(files['/stress/keep.gray']) end
assert(stress.total==3600000)
-- A stale network response must never replace a newer cached result.
local delayed={};local h={request=function(_,o,cb)delayed[#delayed+1]=cb end,cancel_group=function()end};local race=require('soundring.covers').new({http=h,storage=storage,runner=runner,dir='/race',converter='/conv',cache=restart});local chosen
race:fetch('https://i.scdn.co/image/notcached',function(p)chosen=p end);race:fetch('https://i.scdn.co/image/new',function(p)chosen=p end);assert(chosen=='/cache/new.gray');delayed[1]({ok=true,body='old image'});assert(chosen=='/cache/new.gray' and not files['/race/cover-1.img'])
print('Cover cache: hit, restart, LRU, corruption, saturation, stale response and failure fallback passed')
