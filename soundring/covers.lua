-- Async conversion: work remains inside the supervisor's private run directory.
local util=require('core.util')
local M={}
function M.netease_url(url)
 if type(url)~='string' then return nil end
 local base=url:match('^([^?#]+)');if not base then return nil end
 base=base:gsub('^http://','https://')
 local stem,ext=base:match('^(https://p[1-4]%.music%.126%.net/[%w_%%=%-]+/%d+)%.([%a]+)$')
 if not stem or (ext~='jpg' and ext~='jpeg' and ext~='png') then return nil end
 return stem..'.'..ext
end
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
  local spotify_ok=type(url)=='string' and url:match('^https://i%.scdn%.co/image/[%w]+$');local netease_ok=M.netease_url(url);if netease_ok then url=netease_ok end
  if not spotify_ok and not netease_ok then callback(nil,'unsupported_cover_url');return end
  local cache_id=spotify_ok and url:match('/image/([%w]+)$') or nil
  if o.cache and cache_id then local ok,path=pcall(o.cache.get,o.cache,cache_id);if ok and path then if self.current and not self.current_cached then o.storage:remove(self.current) end;self.current=path;self.current_cached=true;self.current_id=cache_id;callback(path);return end end
  local function request(attempt)
  o.http:request({url=url,method='GET',timeout=15,max_bytes=2097152,group='cover-'..tostring(self)},function(r)
   if gen~=self.generation then return end
   if r and r.error=='request queue full' and attempt==0 then self.retry={generation=gen,at=(o.now or os.time)()+2,run=function()request(1)end};return end
   if not r or not r.ok or not r.body or #r.body==0 then callback(nil,'cover_download_failed');return end
   local prefix=o.dir..'/'..(o.prefix or 'cover')..'-'..gen;local job={generation=gen,input=prefix..'.img',output=prefix..'.gray',script=prefix..'.sh',worker=prefix..'.worker.pid',cancel=prefix..'.cancel',done=prefix..'.done',rc=prefix..'.rc',callback=callback,cache_id=cache_id,started=(o.now or os.time)()}
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
  request(0)
 end
 function self:poll()
  local keep={};local now=(o.now or os.time)()
  if self.retry and now>=self.retry.at then local retry=self.retry;self.retry=nil;if retry.generation==self.generation then retry.run() end end
  for _,job in ipairs(self.pending)do
   if job.failed or o.storage:exists(job.done) or now-job.started>30 then
    local ok=not job.failed and o.storage:exists(job.done) and tonumber(o.storage:read(job.rc,32) or '')==0
    local timed_out=not o.storage:exists(job.done) and not job.failed
    if timed_out then cancel(job) else for _,p in ipairs({job.input,job.script,job.done,job.rc,job.worker,job.cancel})do o.storage:remove(p) end end
    if ok and job.generation==self.generation and not job.cancelled then
     local path;if o.cache and job.cache_id then local raw=o.storage:read(job.output,360001);if raw and #raw==360000 then local cached_ok,cached=pcall(o.cache.put,o.cache,job.cache_id,raw,self.current_cached and self.current_id or nil);if cached_ok then path=cached end end end
     if self.current and not self.current_cached then o.storage:remove(self.current) end
     if path then o.storage:remove(job.output);self.current=path;self.current_cached=true;self.current_id=job.cache_id else self.current=job.output;self.current_cached=false;self.current_id=nil end;job.callback(self.current)
    else if not timed_out then o.storage:remove(job.output) end;if job.generation==self.generation and not job.cancelled then job.callback(nil,'cover_decode_failed') end end
   else keep[#keep+1]=job end
  end
  self.pending=keep
 end
 function self:clear()
  self.generation=self.generation+1
  self.retry=nil
  for _,job in ipairs(self.pending)do if not job.cancelled then cancel(job);job.cancelled=true end end
  if o.http.cancel_group then o.http:cancel_group('cover-'..tostring(self)) end
  if self.current and not self.current_cached then o.storage:remove(self.current) end;self.current=nil;self.current_cached=false;self.current_id=nil
 end
 return self
end
return M
