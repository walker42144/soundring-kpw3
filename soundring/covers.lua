-- Async conversion: work remains inside the supervisor's private run directory.
local util=require('core.util')
local M={}
function M.new(o)
 assert(o and o.http and o.storage and o.runner and o.dir and o.converter)
 local self={generation=0,pending={}}
 local function cancel(job)
  o.storage:write(job.cancel,'1\n')
  if o.runner.cancel_http_async then o.runner:cancel_http_async({pid=job.worker,worker=job.worker}) end
 end
 function self:fetch(url,callback)
  self.generation=self.generation+1;local gen=self.generation
  if o.http.cancel_group then o.http:cancel_group('cover-'..tostring(self)) end
  for _,job in ipairs(self.pending)do if not job.cancelled then cancel(job);job.cancelled=true end end
  local spotify_ok=type(url)=='string' and url:match('^https://i%.scdn%.co/image/[%w]+$');local netease_ok=type(url)=='string' and url:match('^https://p[1-4]%.music%.126%.net/[%w_%%=%-]+/%d+%.jpg$')
  if not spotify_ok and not netease_ok then callback(nil,'unsupported_cover_url');return end
  o.http:request({url=url,method='GET',timeout=15,max_bytes=2097152,group='cover-'..tostring(self)},function(r)
   if gen~=self.generation then return end
   if not r or not r.ok or not r.body or #r.body==0 then callback(nil,'cover_download_failed');return end
   local prefix=o.dir..'/'..(o.prefix or 'cover')..'-'..gen;local job={generation=gen,input=prefix..'.img',output=prefix..'.gray',script=prefix..'.sh',worker=prefix..'.worker.pid',cancel=prefix..'.cancel',done=prefix..'.done',rc=prefix..'.rc',callback=callback,started=(o.now or os.time)()}
   if not o.storage:write(job.input,r.body) then callback(nil,'cover_write_failed');return end
   local q=util.shell_quote;local cleanup='rm -f '..table.concat({q(job.input),q(job.output),q(job.done),q(job.rc),q(job.cancel),q(job.script),q(job.worker)},' ')
   local command=(o.runner.timeout_script and ('sh '..q(o.runner.timeout_script)..' 12 ') or '')..q(o.converter)..' '..q(job.input)..' '..q(job.output)..' 600 600'
   local script='#!/bin/sh\numask 077\ntrap '..q(cleanup..'; exit 143')..' TERM INT HUP\n[ ! -f '..q(job.cancel)..' ] || { '..cleanup..'; exit 0; }\n'..command..' >/dev/null 2>&1\nrc=$?\nrm -f '..q(job.input)..'\n[ ! -f '..q(job.cancel)..' ] || { '..cleanup..'; exit 0; }\necho "$rc" > '..q(job.rc)..'\n: > '..q(job.done)..'\n'
   if not o.storage:write(job.script,script) then o.storage:remove(job.input);callback(nil,'cover_write_failed');return end
   o.storage:chmod(job.script,'700');self.pending[#self.pending+1]=job
   local launched=o.runner:spawn_script(job.script,job.worker)
   if launched~=nil and launched~=0 and launched~=true then job.failed=true end
  end)
 end
 function self:poll()
  local keep={};local now=(o.now or os.time)()
  for _,job in ipairs(self.pending)do
   if job.failed or o.storage:exists(job.done) or now-job.started>30 then
    local ok=not job.failed and o.storage:exists(job.done) and tonumber(o.storage:read(job.rc,32) or '')==0
    local timed_out=not o.storage:exists(job.done) and not job.failed
    if timed_out then cancel(job) else for _,p in ipairs({job.input,job.script,job.done,job.rc,job.worker,job.cancel})do o.storage:remove(p) end end
    if ok and job.generation==self.generation and not job.cancelled then
     if self.current then o.storage:remove(self.current) end;self.current=job.output;job.callback(job.output)
    else if not timed_out then o.storage:remove(job.output) end;if job.generation==self.generation and not job.cancelled then job.callback(nil,'cover_decode_failed') end end
   else keep[#keep+1]=job end
  end
  self.pending=keep
 end
 function self:clear()
  self.generation=self.generation+1
  for _,job in ipairs(self.pending)do if not job.cancelled then cancel(job);job.cancelled=true end end
  if o.http.cancel_group then o.http:cancel_group('cover-'..tostring(self)) end
  if self.current then o.storage:remove(self.current);self.current=nil end
 end
 return self
end
return M
