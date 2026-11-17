local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local pending={};local started={};local records={seed={version=1,id='seed',aliases={}}};local changed=0
local spotify={artist=function(_,id,cb)started[#started+1]=id;pending[id]=cb end};local http={request=function(_,q,cb)cb({ok=false})end,cancel_group=function()end}
local covers={clear=function()end,fetch=function()error('unexpected image')end};local store={dir='/a',load=function(_,id)return records[id]end,image_path=function(_,id)return '/a/'..id..'.gray'end,save=function(_,id,v)records[id]=v;return true end};local storage={exists=function()return false end}
local s=require('soundring.artist_info').new({spotify=spotify,http=http,json=require('core.json'),store=store,covers=covers,storage=storage,changed=function()changed=changed+1 end})
s:set_track({{id='seed',name='First'},{id='other',name='Second'}});assert(started[1]=='seed' and #started==1);pending.seed({ok=true,data={}});assert(started[2]=='other');s:select(1);assert(s.index==2);s:select(-1);assert(s.index==1)
s:set_track({{id='third',name='Third'}});assert(started[3]=='third');pending.other({ok=true,data={}});assert(not records.other and s.items[1].id=='third');pending.third({ok=true,data={}});assert(records.third and changed>0)
print('Artist info: seed refresh, sequential loading, switching and stale callbacks passed')

-- Biography is accepted only if the Wikidata Spotify ID matches.
local json=require('core.json');local aliases={};local store2={dir='/a',load=function()end,image_path=function()return '/a/x.gray'end,save=function()return true end,save_alias=function(_,id,name,alias)aliases[#aliases+1]=alias end}
local expected='abc123';local function responder(_,req,cb)
 local u=req.url;local v
 if u:find('musicbrainz.org/ws/2/artist/?',1,true)then v={artists={{name='Artist',id='12345678-abcd',score=100}}}
 elseif u:find('musicbrainz.org/ws/2/artist/',1,true)then v={relations={{type='wikidata',url={resource='https://www.wikidata.org/wiki/Q42'}}}}
 elseif u:find('wikidata.org',1,true)then v={entities={Q42={claims={P1902={{mainsnak={datavalue={value=expected}}}}},labels={zh={value='中文艺人'}},sitelinks={zhwiki={title='中文艺人'}}}}}
 else v={query={pages={{extract='中文介绍。更多资料。'}}}} end
 cb({ok=true,body=json.encode(v)})
end
local ss=require('soundring.artist_info').new({spotify=spotify,http={request=responder},json=json,store=store2,covers=covers,storage=storage,changed=function()end});ss.generation=1
local a={id='abc123',name='Artist'};ss:bio(1,a,function()end);assert(a.bio=='中文介绍。' and aliases[1]=='中文艺人')
expected='different';aliases={};a.bio=nil;ss:bio(1,a,function()end);assert(not a.bio and #aliases==0)
print('Artist biography: Spotify ID verification gates biography and Chinese alias')

local domestic_http={request=function(_,q,cb)assert(q.url:find('id=4292',1,true));cb({ok=true,body=json.encode({briefDesc='中文歌手。后续介绍。'})})end}
local ds=require('soundring.artist_info').new({spotify=spotify,http=domestic_http,json=json,store=store2,covers=covers,storage=storage,changed=function()end});ds.generation=1
local da={id='abc',netease_id='4292'};local success;ds:domestic_bio(1,da,function(ok)success=ok end);assert(success and da.bio=='中文歌手。' and da.bio_source=='netease')
local unsafe={id='abc',netease_id='../../bad'};ds:domestic_bio(1,unsafe,function(ok)success=ok end);assert(not success and not unsafe.bio)
print('Domestic biography: confirmed numeric artist ID required, malformed IDs rejected')

local saved={version=1,id='cached',aliases={'原名'},bio='原资料',checked_at=os.time()};local freshstore={dir='/a',load=function()return saved end,image_path=function()return '/a/x.gray'end,save=function()return true end};local requestcb
local fs=require('soundring.artist_info').new({spotify={artist=function(_,id,cb)requestcb=cb end},http=http,json=json,store=freshstore,covers=covers,storage=storage,changed=function()end});fs:set_track({{id='cached',name='Name'}});assert(not requestcb and fs.items[1].bio=='原资料');fs:refresh();assert(requestcb and fs.items[1].bio=='原资料');requestcb({ok=false});assert(fs.items[1].bio=='原资料')
print('Artist refresh: cache retained while refreshing and on failed request')

local query=require('soundring.lyrics_online').queries({name='晴天',artist='Jay Chou',artist_aliases={'周杰倫'}});assert(query[1]=='晴天 周杰倫');local found=false;for _,v in ipairs(query)do if v=='晴天 周杰伦' then found=true end end;assert(found)
print('Verified traditional aliases also search simplified Chinese first')

-- Spotify artist metadata may be forbidden even when the known NetEase ID works.
local st={dir='/a',load=function()return {version=1,id='blocked',aliases={},netease_id='4292'}end,image_path=function()return '/a/x.gray'end,save=function()return true end}
local dh={request=function(_,req,cb)if req.url:find('music.163.com',1,true)then cb({ok=true,body=json.encode({briefDesc='国内艺人介绍。'})})else cb({ok=false})end end,cancel_group=function()end}
local got;local si=require('soundring.artist_info').new({spotify={artist=function(_,id,cb)cb({ok=false,status=403})end},http=dh,json=json,store=st,covers=covers,storage=storage,changed=function(items)got=items[1] end});si:set_track({{id='blocked',name='Known'}});assert(got and got.bio=='国内艺人介绍。','NetEase fallback should not depend on Spotify artist metadata')

local mem={};local img_http={request=function(_,req,cb)cb({ok=true,body=json.encode({artist={id=4292,img1v1Url='https://p2.music.126.net/abc==/123.jpg'}})})end};local img_covers={fetch=function(_,url,cb)cb('/tmp/image.gray')end};local img_store={dir='/a',image_path=function()return '/a/ok.gray'end};local img_storage={read=function()return string.rep('x',360000)end,mkdir_p=function()return true end,write_atomic=function(_,path,data)mem[path]=data;return true end};local image_session=require('soundring.artist_info').new({spotify=spotify,http=img_http,json=json,store=img_store,covers=img_covers,storage=img_storage,changed=function()end});image_session.generation=1;local im={id='spotifyid',netease_id='4292'};local finished=false;image_session:domestic_image(1,im,function()finished=true end);assert(finished and im.image_path=='/a/ok.gray' and #mem[im.image_path]==360000)
print('Artist image: confirmed NetEase identity can populate local gray portrait')
