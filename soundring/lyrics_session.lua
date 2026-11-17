-- Coordinates lyric searches, manual selection and per-Spotify-track choices.
local online=require('soundring.lyrics_online')
local M={};local Session={};Session.__index=Session
function M.new(o)
 assert(o and o.http and o.json and o.load_choice and o.save_choice and o.on_change)
 return setmetatable({opts=o,generation=0,state={status='idle',candidates={}}},Session)
end
function Session:advance()
 local previous=tostring(self)..':'..self.generation
 self.generation=self.generation+1
 if self.opts.http.cancel_group then self.opts.http:cancel_group(previous) end
 return self.generation
end
function Session:request_options(generation)
 local options={};for k,v in pairs(self.opts) do options[k]=v end
 local parent=self.opts.http;local group=tostring(self)..':'..generation
 options.http={request=function(_,request,callback)
  local copy={};for k,v in pairs(request)do copy[k]=v end;copy.group=group
  return parent:request(copy,callback)
 end}
 options.is_current=function()return generation==self.generation end
 return options
end
function Session:update(value) self.state=value;self.opts.on_change(value) end
function Session:cache(id,result,choice) if self.opts.save_cache then pcall(self.opts.save_cache,id,result,choice) end end
function Session:supplement(result,track,generation)
 if result.source~='qq' or not track or not result.lrc or (result.translation and #require('soundring.lyrics').parse(result.translation)>0) then return end
 local now=os.time();local checked=tonumber(result.translation_checked_at)
 if checked and now>=checked and now-checked<21600 then return end
 local options=self:request_options(generation)
 online.translation_fallback(options,track,function(translation)
  if generation~=self.generation or self.state.status~='synced' then return end
  local next_state={};for k,v in pairs(self.state)do next_state[k]=v end;next_state.translation=translation;next_state.translation_checked_at=os.time();if next_state.warning~='choice_not_saved' then self:cache(track.id,next_state,self.opts.load_choice(track.id)) end;self:update(next_state)
 end)
end
function Session:set_track(track)
 local generation=self:advance();self.track=track
 if not track or not track.id or track.id=='' then self:update({status='idle',candidates={}});return end
 self:update({status='loading',candidates={}})
 local choice=self.opts.load_choice(track.id)
 local function auto()
  local options=self:request_options(generation)
  if self.opts.load_local then options.local_lrc=self.opts.load_local(track) end
  options.is_current=function()return generation==self.generation end
  options.on_translation=function(translation)
   if generation~=self.generation or self.state.status~='synced' then return end
   local update={};for k,v in pairs(self.state)do update[k]=v end;update.translation=translation;update.translation_checked_at=os.time();if not choice then self:cache(track.id,update,nil) end;self:update(update)
  end
  if self.opts.lyrics_source=='local' then
   local parsed=require('soundring.lyrics').parse(options.local_lrc or '')
   if #parsed>0 then self:update({status='synced',source='local',lrc=options.local_lrc,candidates={}}) else self:update({status='not_found',candidates={}}) end
   return
  end
  online.fetch(options,track,function(result)
   if generation~=self.generation then return end
   if result.status=='synced' and not choice then self:cache(track.id,result,nil) end
   self:update({status=result.status,source=result.source,lrc=result.lrc,translation=result.translation,candidates={}})
  end)
 end
 if self.opts.lyrics_source~='local' and self.opts.load_cache then local ok,cached=pcall(self.opts.load_cache,track.id,choice);if ok and cached then self:update(cached);self:supplement(cached,track,generation);return end end
 if choice then
  online.get(self:request_options(generation),choice,function(result)
   if generation~=self.generation then return end
   if result.ok then self:cache(track.id,result,choice);self:update({status='synced',source=result.source,lrc=result.lrc,translation=result.translation,candidates={},remembered=true});self:supplement(result,track,generation) else auto() end
  end)
 else auto() end
end
function Session:search(source,query)
 if not self.track then return false end
 local generation=self:advance();local track={};for k,v in pairs(self.track) do track[k]=v end;if query and query~='' then track.search_query=query end
 self:update({status='searching',source=source,candidates={}})
 online.search(self:request_options(generation),source,track,function(result)
  if generation~=self.generation then return end
  if result.ok then self:update({status='choose',source=source,candidates=result.candidates})
  else self:update({status='search_error',source=source,error=result.error,candidates={}}) end
 end)
 return true
end
function Session:choose(index)
 local state=self.state;local candidate=(state.status=='choose' or state.status=='choice_error') and state.candidates[index]
 if not candidate or not self.track then return false end
 local generation=self.generation;local track_id=self.track.id
 self:update({status='loading_choice',source=candidate.source,candidates=state.candidates})
 online.get(self:request_options(generation),candidate,function(result)
  if generation~=self.generation then return end
  if not result.ok then self:update({status='choice_error',source=candidate.source,error=result.error,candidates=state.candidates});return end
  local selected={source=candidate.source,id=candidate.id};local ok=self.opts.save_choice(track_id,selected)
  if ok and self.opts.save_artist_alias and self.track.artist_id and #(self.track.artists or {})==1 and #(candidate.artists or {})==1 then pcall(self.opts.save_artist_alias,self.track.artist_id,self.track.artist,candidate.artists[1],candidate.source,candidate.artist_ids and candidate.artist_ids[1]) end
  if ok then self:cache(track_id,result,selected) end
  self:update({status='synced',source=result.source,lrc=result.lrc,translation=result.translation,candidates={},remembered=not not ok,warning=not ok and 'choice_not_saved' or nil});self:supplement(result,self.track,generation)
 end)
 return true
end
return M
