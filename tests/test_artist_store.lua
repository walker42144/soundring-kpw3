local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local json=require('core.json');local files={};local storage={read=function(_,p)return files[p]end,write_atomic=function(_,p,v)files[p]=v;return true end,mkdir_p=function()return true end}
local store=require('soundring.artist_store').new({storage=storage,json=json,dir='/artists'})
assert(not store:save_alias('../oops','A','B'));assert(store:save_alias('abc','Ronghao Li','李荣浩'));assert(store:save_alias('abc','Ronghao Li','李榮浩'));assert(store:save_alias('abc','Ronghao Li','李荣浩'));local v=store:load('abc');assert(#v.aliases==2 and v.aliases[1]=='李荣浩');assert(not store:load('other'));files['/artists/abc.json']='broken';assert(not store:load('abc'))
print('Artist store: bounded atomic records, verified aliases, corrupt fallback passed')

assert(store:save_alias('chinese','Jay Chou','周杰倫'));assert(store:display_name('chinese','Jay Chou')=='周杰伦');assert(store:display_name('none','Original')=='Original')
print('Artist display: verified Chinese aliases render simplified without changing original metadata')
local sizes={['/artists/old.gray']=360000,['/artists/old.json']=500};local fs={read=function()end,list_dir=function()return {'old.gray','old.json'}end,file_size=function(_,p)return sizes[p]end};local capped=require('soundring.artist_store').new({storage=fs,json=json,dir='/artists',image_budget_bytes=400000});assert(not capped:can_cache_image('new',360000));assert(capped:can_cache_image('old',360000));assert(sizes['/artists/old.gray']==360000 and sizes['/artists/old.json']==500)
print('Artist cache: portrait growth bounded without deleting images or aliases')
