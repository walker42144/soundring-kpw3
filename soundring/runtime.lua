-- Device-independent event loop. Callers own initialization and safe cleanup.
local View=require('soundring.view')
local M={}
function M.run(o)
 assert(o and o.app and o.display and o.touch and o.http and o.clock)
 local dirty=true;local full=true;local running=true;local sleeping=false;local reconcile_at;local zones={};local last_poll=o.clock:now();local trial_started=last_poll;local last_network_check=0;local interval=o.interval or 5;local last_heartbeat=-math.huge
 o.app.o.changed=function()dirty=true end
 o.app.state.trial_notice=(o.session_limit and o.session_limit>0) and math.ceil(o.session_limit/60) or nil;o.app:refresh()
 while running do
  local now=o.clock:now()
  local heartbeat_now=(o.clock.monotonic and o.clock:monotonic()) or now
  if o.heartbeat and heartbeat_now-last_heartbeat>=10 then o.heartbeat(sleeping);last_heartbeat=heartbeat_now end
  if o.power then
   for _,event in ipairs(o.power:poll_events()) do
    if event=='button' then event=sleeping and 'wake' or 'sleep' end
    if event=='sleep' and not sleeping then
     sleeping=true;if o.heartbeat then o.heartbeat(true);last_heartbeat=heartbeat_now end;o.http.suspended=true;zones={};o.power:cancel_pending_reconcile();o.display:begin_frame(true)
     o.display:text({x=0,y=o.display.height*.48,w=o.display.width,size=36,text='SoundRing',align='center',color='ink',bg='paper'})
     if not o.display:flush({full=true}) then return false,'screensaver_failed' end
     if not o.power:set_hold(false) then return false,'power_hold_failed' end;reconcile_at=now+2
    elseif event=='wake' and sleeping then
     o.power:cancel_pending_reconcile();if not o.power:set_hold(true) then return false,'power_hold_failed' end
     sleeping=false;if o.heartbeat then o.heartbeat(false);last_heartbeat=heartbeat_now end;o.http.suspended=false;dirty=true;full=true;last_poll=now;o.app:refresh();if o.app.lyrics and o.app.state.track then o.app.lyrics:set_track(o.app.state.track) end;reconcile_at=now+2
    end
   end
   if reconcile_at and now>=reconcile_at then o.power:reconcile(sleeping);reconcile_at=nil end
  end
  if o.app.state.trial_notice and now-trial_started>=10 then o.app.state.trial_notice=false;dirty=true end
  if not sleeping and o.network_status and now-last_network_check>=30 then last_network_check=now;local label=o.network_status();if label~=o.app.state.wifi_label then o.app.state.wifi_label=label;dirty=true end end
  if not sleeping and o.app.state.playing and o.app.state.progress_anchor_time then
   local s=o.app.state;local old=s.progress_ms or 0;local estimated=math.min(s.duration_ms or 0,(s.progress_anchor_ms or 0)+math.max(0,now-s.progress_anchor_time)*1000)
   s.progress_ms=estimated
   if math.floor(old/60000)~=math.floor(estimated/60000) or (old<(s.lyric_next_ms or math.huge) and estimated>=(s.lyric_next_ms or math.huge)) or (old<(s.duration_ms or 0) and estimated>=(s.duration_ms or 0)) then dirty=true end
  end
  if not sleeping and o.app.reconcile_at and now>=o.app.reconcile_at then o.app.reconcile_at=nil;o.app:refresh() end
  if not sleeping and now-last_poll>=interval then last_poll=now;o.app:refresh() end
  o.http:poll(not sleeping)
  if not sleeping and o.covers then o.covers:poll() end
  if not sleeping and o.artist_covers then o.artist_covers:poll() end
  if dirty and not sleeping then
   local next_zones,err=View.render(o.display,o.app.state,full)
   if not next_zones then return false,err end
   zones=next_zones;dirty=false;full=false
  end
  for _,event in ipairs(o.touch:poll(250) or {}) do
   if not sleeping and event.type=='tap' then
    local action,value=View.hit(zones,event.x,event.y)
    if action=='exit' then running=false
    elseif action then o.app:action(action,value) end
   end
  end
  if o.should_stop and o.should_stop() then running=false end
 end
 return true
end
return M
