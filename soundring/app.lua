-- App state and user actions, independent of Kindle I/O for testability.
local Lyrics=require('soundring.lyrics');local LyricsSession=require('soundring.lyrics_session')
local M={};local App={};App.__index=App
-- Cursor positions are UTF-8 byte boundaries; keys themselves are ASCII.
local function cursor(s)
 local t=s.search_text or '';local p=math.max(0,math.min(#t,tonumber(s.search_cursor) or #t))
 while p>0 and p<#t and (t:byte(p+1) or 0)>=128 and (t:byte(p+1) or 0)<192 do p=p-1 end
 return p
end
local function previous(t,p)
 if p<=0 then return 0 end
 local i=p;while i>1 and t:byte(i)>=128 and t:byte(i)<192 do i=i-1 end;return i-1
end
local function following(t,p)
 if p>=#t then return #t end
 local i=p+2;while i<=#t and t:byte(i)>=128 and t:byte(i)<192 do i=i+1 end;return i-1
end
function M.new(o)
 assert(o and o.spotify and o.http and o.json and o.load_choice and o.save_choice)
 local self=setmetatable({o=o,state={page='now',status='loading',lyrics_visible=false,items={},playing=false},track_generation=0,request_generation=0},App)
 self.lyrics=LyricsSession.new({http=o.http,json=o.json,now=o.now,load_choice=o.load_choice,save_choice=o.save_choice,load_cache=o.load_cache,save_cache=o.save_cache,load_local=o.load_local,save_artist_alias=o.save_artist_alias,lyrics_source=o.lyrics_source,on_change=function(s)
  self.state.lyrics=s;if s.status=='synced' then self.state.lyric_lines=Lyrics.with_translation(s.lrc,s.translation);if self.state.page=='lyrics_search' then self.state.page='now';self.state.lyrics_visible=true end else self.state.lyric_lines=nil end;self:changed()
 end})
 return self
end
function App:changed() if self.o.changed then self.o.changed(self.state) end end
function App:trace(message) if self.o.log then self.o.log:info('play_diagnostic '..message) end end
function App:refresh_queue(force)
 if not self.o.spotify.queue or not self.state.track then return end
 if self.queue_inflight then self.queue_queued=true;return end
 local now=self.o.now and self.o.now() or os.time();if not force and self.queue_next and now<self.queue_next then return end
 self.queue_next=now+30;self.queue_inflight=true;self.queue_generation=(self.queue_generation or 0)+1;local gen=self.queue_generation;local tg=self.track_generation
 self.o.spotify:queue(function(q)
  self.queue_inflight=false
  if tg==self.track_generation and gen==self.queue_generation then
   local items=q and q.ok and q.data and q.data.queue;local item=type(items)=='table' and items[1] or nil
   self.state.next_track=type(item)=='table' and type(item.name)=='string' and item.name or nil
   self.state.next_status=(not q or not q.ok or type(items)~='table') and 'unavailable' or not item and 'empty' or 'ready'
   self:changed()
  end
  if self.queue_queued then self.queue_queued=false;self:refresh_queue(true) end
 end)
end
function App:refresh()
 if self.refresh_inflight then self.refresh_queued=true;return end
 self.refresh_inflight=true
 self.request_generation=self.request_generation+1;local gen=self.request_generation
 self.o.spotify:playback(function(r)
  self.refresh_inflight=false
  if gen~=self.request_generation then if self.refresh_queued then self.refresh_queued=false;self:refresh() end;return end
  if self.refresh_queued then self.refresh_queued=false;self:refresh();return end
  if not r.ok then self.state.status=r.error or 'network';self:changed();return end
  if not r.data or not r.data.item or type(r.data.item.id)~='string' or r.data.item.id=='' then self.track_generation=self.track_generation+1;local s=self.state;s.track=nil;s.cover_path=nil;s.playing=false;s.duration_ms=0;s.progress_ms=0;s.progress_anchor_ms=nil;s.progress_anchor_time=nil;s.lyric_next_ms=nil;s.next_track=nil;s.next_status=nil;s.liked=false;if self.o.covers then self.o.covers:clear() end;s.status='no_playback';self.lyrics:set_track(nil);if self.artist_info then self.artist_info:set_track({}) end;self:changed();return end
  local p=r.data;local t=p.item;local now=self.o.now and self.o.now() or os.time();local not_confirmed=false;if self.expected_track then self:trace('state observed='..t.id..' expected='..self.expected_track.id);if t.id~=self.expected_track.id then if now<self.expected_track.until_time then self.reconcile_at=now+2;return end;not_confirmed=true end end;self.expected_track=nil;local artist=t.artists and t.artists[1] and t.artists[1].name or ''
  local previous=self.state.track and self.state.track.id;local id=t.id
  local first=t.artists and t.artists[1];local artist_id=first and first.id;local record=artist_id and self.o.load_artist and self.o.load_artist(artist_id)
  local display_names={};for _,entry in ipairs(t.artists or {})do if type(entry.name)=='string' then display_names[#display_names+1]=(self.o.artist_display_name and entry.id and self.o.artist_display_name(entry.id,entry.name)) or entry.name end end
  self.state.track={id=id,name=t.name or '',artist=artist,display_artist=table.concat(display_names,' / '),artist_id=artist_id,artist_aliases=record and record.aliases or {},artists=t.artists or {},album=t.album and t.album.name or '',duration=(t.duration_ms or 0)/1000,cover=t.album and t.album.images and t.album.images[1] and t.album.images[1].url}
  self.state.status=not_confirmed and 'play_not_confirmed' or 'ready';self.state.progress_ms=p.progress_ms or 0;self.state.progress_anchor_ms=self.state.progress_ms;self.state.progress_anchor_time=self.o.now and self.o.now() or os.time();self.state.duration_ms=t.duration_ms or 0;self.state.playing=p.is_playing;self.state.device=p.device and p.device.name or '';self.state.volume=p.device and type(p.device.volume_percent)=='number' and p.device.volume_percent or nil;self.state.shuffle=p.shuffle_state;self.state.repeat_mode=p.repeat_state or 'off'
  if previous~=id then
   self.track_generation=self.track_generation+1;local tg=self.track_generation
   self.state.cover_path=nil;self.state.next_track=nil
   self.state.next_status='loading';self:refresh_queue(true)
   if self.o.covers then self.o.covers:fetch(self.state.track.cover,function(path) if tg==self.track_generation then self.state.cover_path=path;self:changed() end end) end
   self.lyrics:set_track(self.state.track)
   if self.artist_info then self.artist_info:set_track(self.state.track.artists) end
   if id then self.o.spotify:liked(id,function(res)if tg==self.track_generation and res.ok then self.state.liked=res.data and res.data[1] or false;self:changed() end end) end
  end
  if previous==id then self:refresh_queue(false) end
  self:changed()
 end)
end
function App:write_result(r)
 if not r.ok then self.state.status=r.error or 'command_failed';self:changed();return end
 self.request_generation=self.request_generation+1;self:refresh()
 self.reconcile_at=(self.o.now and self.o.now() or os.time())+2
end
function App:action(name,value)
 local s=self.state;local sp=self.o.spotify
 if name=='artist_previous' and self.artist_info then self.artist_info:select(-1)
 elseif name=='artist_next' and self.artist_info then self.artist_info:select(1)
 elseif name=='refresh' then if self.artist_info then self.artist_info:refresh() end;self:refresh_queue(true);self:refresh()
 elseif name=='playlist_back' then s.restore_playlist_offset=s.playlists_saved_local or 0;self:action('playlists',s.playlists_saved_offset or 0)
 elseif name=='lyrics' then s.lyrics_visible=not s.lyrics_visible;self:changed()
 elseif name=='lyrics_search' then s.page='lyrics_search';s.lyrics_offset=0;self.lyrics:search(value or 'qq');self:changed()
 elseif name=='lyrics_keyword' then s.lyrics_source_query=(s.lyrics and s.lyrics.source=='netease') and 'netease' or 'qq';s.search_text='';s.search_cursor=0;s.page='lyrics_input';self:changed()
 elseif name=='lyrics_submit' then s.page='lyrics_search';s.lyrics_offset=0;self.lyrics:search(s.lyrics_source_query or 'qq',s.search_text or '');self:changed()
 elseif name=='lyrics_prev' then s.lyrics_offset=math.max(0,(s.lyrics_offset or 0)-6);self:changed()
 elseif name=='lyrics_next' then local n=#((s.lyrics and s.lyrics.candidates) or {});if (s.lyrics_offset or 0)+6<n then s.lyrics_offset=(s.lyrics_offset or 0)+6 end;self:changed()
 elseif name=='lyrics_choose' then self.lyrics:choose(value)
 elseif name=='lyrics_back' then s.page='now';self:changed()
 elseif name=='play' then sp:control(s.playing and 'pause' or 'play',function(r)self:write_result(r)end)
 elseif name=='previous' or name=='next' then sp:control(name,function(r)self:write_result(r)end)
 elseif name=='shuffle' then sp:shuffle(not s.shuffle,function(r)self:write_result(r)end)
 elseif name=='repeat' then local nextmode=({off='context',context='track',track='off'})[s.repeat_mode] or 'off';sp:repeat_mode(nextmode,function(r)self:write_result(r)end)
 elseif name=='like' and s.track and s.track.id then sp:set_liked(s.track.id,not s.liked,function(r)if r.ok then s.liked=not s.liked;self:changed() else self:write_result(r) end end)

 elseif name=='volume' and type(s.volume)=='number' then sp:volume(math.max(0,math.min(100,s.volume+(tonumber(value) or 0))),function(r)self:write_result(r)end)
 elseif name=='devices' then s.page='devices';s.list_offset=0;s.list_remote_offset=0;s.list_has_next=false;s.status='loading';s.items={};self:changed();sp:devices(function(r)if s.page~='devices' then return end;s.items=r.ok and (r.data and r.data.devices or {}) or {};s.status=r.ok and 'ready' or r.error;self:changed()end)
 elseif name=='transfer' then sp:transfer(value,function(r)if r.ok then s.page='now' end;self:write_result(r)end)
 elseif name=='playlists' then s.list_remote_offset=tonumber(value) or 0;s.list_offset=0;s.page='playlists';s.status='loading';s.items={};self:changed();local offset=s.list_remote_offset;sp:playlists(offset,function(r)if s.page~='playlists' or s.list_remote_offset~=offset then return end;s.items=r.ok and (r.data and r.data.items or {}) or {};s.list_total=r.ok and r.data and tonumber(r.data.total) or nil;if s.page=='playlists' and s.restore_playlist_offset then s.list_offset=math.min(s.restore_playlist_offset,math.max(0,math.floor((#s.items-1)/10)*10));s.restore_playlist_offset=nil end;if s.list_return_tail then s.list_offset=math.max(0,math.floor((#s.items-1)/10)*10);s.list_return_tail=nil end;s.list_has_next=r.ok and r.data and type(r.data.next)=='string';s.status=r.ok and 'ready' or r.error;self:changed()end)
 elseif name=='playlist_items' then if type(value)=='string' then s.playlists_saved_offset=s.list_remote_offset;s.playlists_saved_local=s.list_offset;s.playlist_id=value;s.list_remote_offset=0 else s.list_remote_offset=tonumber(value) or 0 end;s.list_offset=0;s.page='playlist_items';s.status='loading';s.items={};self:changed();local offset=s.list_remote_offset;local id=s.playlist_id;sp:playlist_items(id,offset,function(r)if s.page~='playlist_items' or s.list_remote_offset~=offset or s.playlist_id~=id then return end;s.items=r.ok and (r.data and r.data.items or {}) or {};s.list_total=r.ok and r.data and tonumber(r.data.total) or nil;if s.list_return_tail then s.list_offset=math.max(0,math.floor((#s.items-1)/10)*10);s.list_return_tail=nil end;s.list_has_next=r.ok and r.data and type(r.data.next)=='string';s.status=r.ok and 'ready' or (r.status==403 and 'playlist_forbidden' or r.error);self:changed()end)
 elseif name=='search_open' then s.page='search_input';s.search_text=s.search_text or '';s.search_cursor=#s.search_text;self:changed()
 elseif name=='search_key' then local t=s.search_text or '';local p=cursor(s);local v=tostring(value or '');s.search_text=t:sub(1,p)..v..t:sub(p+1);s.search_cursor=p+#v;self:changed()
 elseif name=='search_delete' then local t=s.search_text or '';local p=cursor(s);local q=previous(t,p);s.search_text=t:sub(1,q)..t:sub(p+1);s.search_cursor=q;self:changed()
 elseif name=='search_left' then s.search_cursor=previous(s.search_text or '',cursor(s));self:changed()
 elseif name=='search_right' then s.search_cursor=following(s.search_text or '',cursor(s));self:changed()
 elseif name=='search_submit' then self:action('search',0)
 elseif name=='search' then s.list_remote_offset=tonumber(value) or 0;s.list_offset=0;s.page='search';s.status='loading';s.items={};self:changed();local offset=s.list_remote_offset;local term=s.search_text or '';sp:search(term,offset,function(r)if s.page~='search' or s.list_remote_offset~=offset or s.search_text~=term then return end;local data=r.data and r.data.tracks;s.items=r.ok and (data and data.items or {}) or {};s.list_has_next=r.ok and data and type(data.next)=='string';s.status=r.ok and 'ready' or r.error;self:changed()end)
 elseif name=='list_next' then local step=s.page=='devices' and 8 or 10;if (s.list_offset or 0)+step<#(s.items or {}) then s.list_offset=(s.list_offset or 0)+step;self:changed() elseif s.list_has_next then self:action(s.page,(s.list_remote_offset or 0)+(s.page=='search' and 10 or 20)) end
 elseif name=='list_prev' then local step=s.page=='devices' and 8 or 10;if (s.list_offset or 0)>0 then s.list_offset=math.max(0,(s.list_offset or 0)-step);self:changed() elseif (s.list_remote_offset or 0)>0 then s.list_return_tail=true;self:action(s.page,math.max(0,s.list_remote_offset-(s.page=='search' and 10 or 20))) end
 elseif name=='play_uri' then
  local selection=type(value)=='table' and value or {uri=value};local uri=selection.uri;local context=selection.context
  local safe_id=type(uri)=='string' and uri:match('^spotify:track:([%w]+)$');self:trace('select track='..tostring(safe_id or 'invalid')..' page='..tostring(s.page)..' context='..tostring(context and 'yes' or 'no'))
  if self.play_inflight then self.play_queued=selection;return end
  self.play_inflight=true;sp:play_uri(uri,function(r)self:trace('result track='..tostring(safe_id or 'invalid')..' ok='..tostring(r and r.ok)..' http='..tostring(r and r.status or 0)..' error='..tostring(r and r.error or 'none'));self.play_inflight=false;local queued=self.play_queued;self.play_queued=nil;if queued then self:action('play_uri',queued);return end;if r.ok then if safe_id then self.expected_track={id=safe_id,until_time=(self.o.now and self.o.now() or os.time())+10} end;s.page='now' end;self:write_result(r)end,context)
 elseif name=='now' then s.page='now';self:changed();if sp.playback then self:refresh() end end
end
return M
