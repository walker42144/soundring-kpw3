local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local json=require('core.json');local files={};local writes=0;local storage={read=function(_,p)return files[p]end,write_atomic=function(_,p,v)files[p]=v;writes=writes+1;return true end,mkdir_p=function()return true end}
local cache=require('soundring.lyrics_cache').new({storage=storage,json=json,dir='/cache'});local result={source='qq',lrc='[00:01.00] original',translation='[00:01.00] 译文'}
assert(cache:save('abc',result,nil));local c=cache:load('abc',nil);assert(c.cached and c.lrc==result.lrc and c.translation==result.translation)
assert(not cache:load('../bad',nil));assert(not cache:save('../bad',result,nil));assert(not cache:load('abc',{source='qq',id='one'}))
local choice={source='netease',id='123'};assert(cache:save('abc',{source='netease',lrc='[00:02] new'},choice));assert(cache:load('abc',choice).remembered);assert(not cache:load('abc',nil));assert(not cache:load('abc',{source='netease',id='124'}))
local preserve,perr=cache:save('abc',{source='qq',lrc='[00:01] automatic'},nil);assert(not preserve and perr=='manual_cache_preserved' and cache:load('abc',choice))
files['/cache/abc.json']='{broken';assert(not cache:load('abc',choice));assert(not cache:save('abc',{source='qq',lrc='no timestamp'},nil))
local bad,whybad=cache:save('abc',{source='qq',lrc='[00:01] automatic'},nil);assert(not bad and whybad=='existing_cache_invalid' and files['/cache/abc.json']=='{broken')
local online=require('soundring.lyrics_online');local fetches=0;local callbacks={};online.fetch=function(o,t,cb)fetches=fetches+1;callbacks[t.id]=cb end;online.search=function(o,src,t,cb)cb({ok=true,candidates={{source='netease',id='123'}}})end;online.get=function(o,sel,cb)cb({ok=true,source=sel.source,lrc='[00:02] selected'})end
local choices={};local Session=require('soundring.lyrics_session');local x=Session.new({http={},json=json,load_choice=function(id)return choices[id]end,save_choice=function(id,v)choices[id]=v;return true end,load_cache=function(id,c)return cache:load(id,c)end,save_cache=function(id,v,c)return cache:save(id,v,c)end,on_change=function()end})
local a={id='a',name='A',artist='Singer',duration=100};x:set_track(a);assert(fetches==1);callbacks.a({status='synced',source='qq',lrc='[00:01] auto',translation='[00:01] translated'});assert(cache:load('a',nil).translation)
x:set_track(a);assert(fetches==1 and x.state.cached and x.state.lrc=='[00:01] auto')
x:search('netease');assert(x:choose(1));assert(x.state.lrc=='[00:02] selected');x:set_track(a);assert(fetches==1 and x.state.cached and x.state.source=='netease')
local b={id='b',name='B',artist='Singer',duration=100};x:set_track(b);x:set_track(a);callbacks.b({status='synced',source='qq',lrc='[00:01] stale'});assert(not cache:load('b',nil) and x.state.source=='netease')
print('Lyrics cache: validated atomic storage, offline reuse, manual replacement and stale callbacks')
local budgetfiles={['/bounded/existing.json']=string.rep('x',300)};local boundedstore={read=function(_,p)return budgetfiles[p]end,write_atomic=function(_,p,v)budgetfiles[p]=v;return true end,mkdir_p=function()return true end,list_dir=function()return {'existing.json'}end,file_size=function(_,p)return budgetfiles[p] and #budgetfiles[p] end};local bounded=require('soundring.lyrics_cache').new({storage=boundedstore,json=json,dir='/bounded',auto_budget_bytes=310});local full,why=bounded:save('auto',{source='qq',lrc='[00:01] automatic'},nil);assert(not full and why=='cache_full' and budgetfiles['/bounded/existing.json']);assert(bounded:save('manual',{source='qq',lrc='[00:01] chosen'},{source='qq',id='choice'}));assert(budgetfiles['/bounded/existing.json'])
print('Lyrics cache: bounded automatic growth preserves existing and manual selections')
-- A failed manual-choice save must never associate new lyrics with the old choice.
local oldchoice={source='netease',id='123'};local staleid='c';local oldtext='[00:03] old';assert(cache:save(staleid,{source='netease',lrc=oldtext},oldchoice))
local y=Session.new({http={},json=json,load_choice=function()return oldchoice end,save_choice=function()return false end,load_cache=function(id,c)return cache:load(id,c)end,save_cache=function(id,v,c)return cache:save(id,v,c)end,on_change=function()end})
y.track={id=staleid,name='C',artist='Singer',duration=100};y.state={status='choose',candidates={{source='netease',id='456'}}};assert(y:choose(1));assert(y.state.warning=='choice_not_saved');assert(cache:load(staleid,oldchoice).lrc==oldtext)
print('Failed choice persistence does not replace the previous saved lyric cache')

-- Cached originals display immediately; translation retries are bounded and stale callbacks ignored.
local pending={};local attempts=0
online.translation_fallback=function(o,t,cb) attempts=attempts+1;pending[t.id]=cb end
assert(cache:save('retry',{source='qq',lrc='[00:01] origin'},nil))
x:set_track({id='retry',name='R',artist='Singer',duration=100});assert(x.state.cached and attempts==1)
pending.retry(nil);assert(cache:load('retry',nil).translation_checked_at)
x:set_track({id='retry',name='R',artist='Singer',duration=100});assert(attempts==1)
local outdated=cache:load('retry',nil);outdated.translation_checked_at=os.time()-21601;assert(cache:save('retry',outdated,nil))
x:set_track({id='retry',name='R',artist='Singer',duration=100});assert(attempts==2)
x:set_track(a);pending.retry('[00:01] stale translation');assert(not cache:load('retry',nil).translation)
x:set_track({id='retry',name='R',artist='Singer',duration=100});pending.retry('[00:01] translation');assert(cache:load('retry',nil).translation)
print('Cached translation retry is throttled and obsolete callbacks cannot overwrite data')
