local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local p=require('soundring.lyrics_online');local j=require('core.json')
assert(p.decode64('WzAwOjAxLjAwXSBoaQ==')=='[00:01.00] hi')
assert(p.matches({name='song',artists={'artist'},duration=181},{name='Song',artist='artist',duration=180}))
assert(not p.matches({name='song (live)',artists={'artist'},duration=181},{name='Song',artist='artist',duration=180}))
local track={name='Song',artist='Artist',duration=180}
local song={name='Song',singer={{name='Artist'}},interval=180,mid='mid1'}
local qq=j.encode({req_1={data={body={song={list={song}}}}}})
local ns={name='Song',artists={{name='Artist'}},duration=180000,id=42}
local net=j.encode({result={songs={ns}}})
local function run(responses,local_lrc)
 local i=0;local http={request=function(_,opt,cb) i=i+1;assert(opt.url:match('^https://'));cb(responses[i] or {ok=false}) end};local output
 p.fetch({http=http,json=j,local_lrc=local_lrc},track,function(result)output=result end)
 return output,i
end
local o,n=run({{ok=true,body=qq},{ok=true,body=j.encode({lyric='WzAwOjAxLjAwXSBoaQ=='})}});assert(o.source=='qq' and n==2)
o,n=run({{ok=false},{ok=true,body=net},{ok=true,body=j.encode({lrc={lyric='[00:01.00] hi'}})}});assert(o.source=='netease' and n==3)
o,n=run({{ok=false},{ok=false}},'[00:01.00] local');assert(o.source=='local' and n==2)
o,n=run({{ok=false},{ok=false}},nil);assert(o.status=='not_found')
print('QQ -> NetEase -> local: strict match, encoding and asynchronous fallback passed')

local candidates={{name='Song',artists={'Artist'},duration=184,id='a',album='Other'},{name='Song',artists={'Artist'},duration=180,id='b',album='Album'}}
local match=p.select_song(candidates,{name='song',artist='artist',duration=180,album='Album'});assert(match.id=='b')
assert(not p.matches({name='Song (live)',artists={'Artist'},duration=180},{name='Song',artist='Artist',duration=180}))
assert(not p.matches({name='Song',artists={'Imitator'},duration=180},{name='Song',artist='Artist',duration=180}))
assert(not p.matches({name='Song',artists={'Artist'},duration=200},{name='Song',artist='Artist',duration=180}))
local duplicate={{name='Song',artists={'Artist'},duration=180,id='a'},{name='Song',artists={'Artist'},duration=180,id='b'}}
local none,why=p.select_song(duplicate,track);assert(not none and why=='ambiguous')
assert(p.matches({name='晴天（Live）',artists={'周杰伦'},duration=180},{name='晴天 (Live)',artist='周杰伦',duration=180}))
print('Matching: artist and version rejection, duration, album, punctuation, ambiguous ties passed')
local target={name='Wonderful Tonight',artist='Eric Clapton',album='Slowhand',duration=220}
assert(p.matches({name='Wonderful Tonigh',artists={'Eric Clapton'},album='Slowhand',duration=220},target))
assert(not p.matches({name='Wonderful Tonight Live',artists={'Eric Clapton'},album='Slowhand',duration=220},target))
assert(not p.matches({name='Wonderful Tonigh',artists={'Other Artist'},album='Slowhand',duration=220},target))
assert(not p.matches({name='Wonderful Tonigh',artists={'Eric Clapton'},album='Other',duration=226},target))
assert(p.matches({name='Wonderful Tonight',artists={'Eric Clapton'},album='Other',duration=227},target))
local winner=p.select_song({{name='Wonderful Tonigh',artists={'Eric Clapton'},album='Slowhand',duration=220,id='a'},{name='Wonderful Tonight',artists={'Eric Clapton'},album='Slowhand',duration=220,id='b'}},target);assert(winner.id=='b')
print('Flexible matching: minor typo, version guard, artist guard, duration, exact-match preference passed')
