local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local online=require('soundring.lyrics_online');online.fetch=function(o,t,cb)cb({status='not_found'})end
local p={calls={}}
function p:playback(cb) cb({ok=true,data={item={id='one',name='Song',artists={{name='Singer'}},album={name='Album'},duration_ms=180000},progress_ms=60000,is_playing=true,device={name='Speaker'},repeat_state='off'}}) end
function p:liked(id,cb)cb({ok=true,data={false}})end
function p:control(a,cb)self.calls[#self.calls+1]=a;cb({ok=false,error='test'})end
function p:shuffle(v,cb)self.calls[#self.calls+1]=v;cb({ok=false,error='test'})end
function p:repeat_mode(v,cb)self.calls[#self.calls+1]=v;cb({ok=false,error='test'})end
function p:set_liked(id,v,cb)self.calls[#self.calls+1]=v;cb({ok=true})end
function p:devices(cb)cb({ok=true,data={devices={{id='d',name='Speaker'}}}})end
local app=require('soundring.app').new({spotify=p,http={},json={},load_choice=function()end,save_choice=function()return true end})
app:refresh();assert(app.state.track.id=='one' and app.state.device=='Speaker' and app.state.liked==false)
app:action('play');assert(p.calls[1]=='pause');app:action('shuffle');assert(p.calls[2]==true);app:action('repeat');assert(p.calls[3]=='context')
app:action('like');assert(app.state.liked);app:action('lyrics');assert(app.state.lyrics_visible)
app:action('devices');assert(app.state.page=='devices' and #app.state.items==1);app:action('now');assert(app.state.page=='now')
print('App controller: playback state, transport, shuffle, repeat, like and device navigation passed')
-- Sequential pagination, including responses arriving after leaving the page.
local paged={}
function paged:playlists(offset,cb)local items={};for i=1,20 do items[i]={id='p'..(offset+i),name='List '..(offset+i)}end;cb({ok=true,data={items=items,next=offset==0 and 'next' or nil}})end
local pages=require('soundring.app').new({spotify=paged,http={},json={},load_choice=function()end,save_choice=function()return true end})
pages:action('playlists');assert(#pages.state.items==20);pages:action('list_next');assert(pages.state.list_offset==10);pages:action('list_next');assert(pages.state.list_remote_offset==20 and pages.state.items[1].id=='p21');pages:action('list_prev');assert(pages.state.list_remote_offset==0 and pages.state.list_offset==10)
pages:action('search_open');pages:action('search_key','A');pages:action('search_key','B');pages:action('search_delete');assert(pages.state.search_text=='A')
pages:action('search_key','B');pages:action('search_key','C');pages:action('search_left');pages:action('search_left');pages:action('search_key','X');assert(pages.state.search_text=='AXBC');pages:action('search_delete');assert(pages.state.search_text=='ABC');pages:action('search_left');pages:action('search_left');assert(pages.state.search_cursor==0);pages:action('search_right');assert(pages.state.search_cursor==1)
pages.state.search_text='A李B';pages.state.search_cursor=#pages.state.search_text;pages:action('search_left');pages:action('search_delete');assert(pages.state.search_text=='AB' and pages.state.search_cursor==1);pages:action('search_right');pages:action('search_right');assert(pages.state.search_cursor==2)
print('App controller: playlist paging and search keyboard passed')

local now=0;local callbacks={};local q={queue=function(_,cb)callbacks[#callbacks+1]=cb end}
local a=require('soundring.app').new({spotify=q,http={},json={},now=function()return now end,load_choice=function()end,save_choice=function()return true end});a.state.track={id='one'};a.track_generation=1
 a:refresh_queue(true);assert(#callbacks==1);a.track_generation=2;a.state.track={id='two'};a:refresh_queue(true);assert(#callbacks==1);callbacks[1]({ok=true,data={queue={{name='stale'}}}});assert(not a.state.next_track and #callbacks==2);callbacks[2]({ok=true,data={queue={{name='fresh'}}}});assert(a.state.next_track=='fresh' and a.state.next_status=='ready')
 a:refresh_queue(true);callbacks[3]({ok=true,data={queue={}}});assert(a.state.next_status=='empty' and not a.state.next_track)
 a:refresh_queue(true);callbacks[4]({ok=false});assert(a.state.next_status=='unavailable' and not a.state.next_track)
 now=100;a:refresh_queue(false);assert(#callbacks==5);callbacks[5]({ok=true,data={queue={}}});a:refresh_queue(false);assert(#callbacks==5)
print('Queue: stale responses rejected, refresh coalescing and empty/error states passed')
