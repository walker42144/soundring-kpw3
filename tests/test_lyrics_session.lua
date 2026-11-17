local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local online=require('soundring.lyrics_online');local session=require('soundring.lyrics_session')
local saved,changes,pending={}, {},{}
online.fetch=function(o,t,cb)pending.auto=cb end
online.search=function(o,s,t,cb)pending.search=cb end
online.get=function(o,c,cb)pending.get=cb end
local x=session.new({http={},json={},load_choice=function(id)return saved[id]end,save_choice=function(id,c)saved[id]=c;return true end,on_change=function(s)changes[#changes+1]=s end})
x:set_track({id='spotify-a',name='Song',artist='Singer',duration=180});assert(x.state.status=='loading')
assert(x:search('qq'));pending.search({ok=true,candidates={{id='abc',source='qq',name='Song'}}});assert(x.state.status=='choose')
assert(x:choose(1));pending.get({ok=true,source='qq',lrc='[00:01.00] lyric'});assert(x.state.status=='synced' and saved['spotify-a'].id=='abc')
x:set_track({id='spotify-a',name='Song',artist='Singer',duration=180});pending.get({ok=true,source='qq',lrc='[00:01.00] lyric'});assert(x.state.remembered)
x:search('qq');local old=pending.search;x:set_track({id='spotify-b',name='Next',artist='Singer',duration=200});old({ok=true,candidates={{id='old'}}});assert(x.state.status=='loading')
pending.auto({status='not_found'});assert(x.state.status=='not_found')
x:search('netease');pending.search({ok=true,candidates={{id='42',source='netease'}}});x:choose(1);pending.get({ok=false,error='no_synced_lyrics'});assert(x.state.status=='choice_error' and not saved['spotify-b'])
print('Lyrics session: manual choice, success-only persistence, reload and stale callback suppression passed')
