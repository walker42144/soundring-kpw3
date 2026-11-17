local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local app={o={},state={page='now',duration_ms=60000,progress_ms=0},count=0}
function app:refresh()self.count=self.count+1 end
function app:action(a,v)self.last=a end
function app:changed()if self.o.changed then self.o.changed(self.state) end end
local d={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end
local n=0;local ok=require('soundring.runtime').run({app=app,display=d,touch={poll=function()n=n+1;return {}end},http={poll=function()end},clock={now=function()return 100 end},should_stop=function()return n>=2 end});assert(ok and app.count>=1)
print('Runtime: startup, refresh, draw and bounded exit passed')
local tick=0;local power={calls={},poll_events=function(self)tick=tick+1;if tick==1 then return {'sleep'} elseif tick==2 then return {'wake'} else return {} end end,cancel_pending_reconcile=function()end,set_hold=function(self,on)self.calls[#self.calls+1]=on;return true end,reconcile=function()end}
local sleepapp={o={},state={page='now',duration_ms=60000,progress_ms=0},count=0};function sleepapp:refresh()self.count=self.count+1 end;function sleepapp:action()end;function sleepapp:changed()if self.o.changed then self.o.changed(self.state)end end
local draws=0;local sd={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do sd[n]=function()end end;function sd:flush()draws=draws+1;return true end
local iter=0;assert(require('soundring.runtime').run({app=sleepapp,display=sd,touch={poll=function()iter=iter+1;return {}end},http={poll=function()end},clock={now=function()return 100+iter end},power=power,should_stop=function()return iter>=3 end}));assert(sleepapp.count==2 and draws>=2);assert(#power.calls==2 and power.calls[1]==false and power.calls[2]==true)
print('Runtime: sleep screen, wake redraw and refresh passed')
local heartbeat_log={};local t=0;local ph={poll_events=function()t=t+1;if t==1 then return {'sleep'} elseif t==2 then return {'wake'} else return {} end end,cancel_pending_reconcile=function()end,set_hold=function()return true end,reconcile=function()end}
local ap={o={},state={page='now'},refresh=function()end,action=function()end};local iter2=0
assert(require('soundring.runtime').run({app=ap,display=d,touch={poll=function()iter2=iter2+1;return {}end},http={poll=function()end},clock={now=function()return 100+iter2 end},power=ph,session_limit=180,heartbeat=function(s)heartbeat_log[#heartbeat_log+1]=s end,should_stop=function()return iter2>=3 end}));assert(ap.state.trial_notice==3);assert(#heartbeat_log>=3 and heartbeat_log[1]==false and heartbeat_log[2]==true and heartbeat_log[3]==false)
print('Heartbeat and sleep marker follow session state; trial notice reflects configured limit')
