#!/usr/bin/env luajit
-- Kindle entrypoint; only run under the reviewed supervisor (not standalone shell).
local function dir(path)return path:match('^(.*)[/\\][^/\\]+$') or '.' end
local appdir=dir(arg[0]);package.path=appdir..'/?.lua;'..appdir..'/?/init.lua;'..package.path
local args={data_dir='/mnt/us/soundring'}
local i=1;while arg[i] do local k=arg[i]
 if k=='--app-dir' then i=i+1;appdir=arg[i]
 elseif k=='--data-dir' then i=i+1;args.data_dir=arg[i]
 elseif k=='--fbink' then i=i+1;args.fbink=arg[i]
 elseif k=='--probe-touch' then args.probe_touch=true
 elseif k=='--probe-display' then args.probe_display=true
 elseif k=='--probe-native-display' then args.probe_native=true end;i=i+1
end
package.path=appdir..'/?.lua;'..appdir..'/?/init.lua;'..package.path
local json=require('core.json');local Storage=require('core.storage');local util=require('core.util');local storage=Storage.new()
local function fonts()return {cjk=appdir..'/assets/fonts/MiSans-Regular.ttf',fallback=appdir..'/assets/fonts/SourceHanSansCN-Medium.ttf',international=appdir..'/assets/fonts/NotoSans-Regular.ttf',latin=appdir..'/assets/fonts/KumbhSans-500.ttf',display=appdir..'/assets/fonts/KumbhSans-600.ttf',library=os.getenv('KDASH_FREETYPE')}end
local function readjson(path)
 local raw,err=storage:read(path,262144);if not raw then return nil,err end
 local ok,data=pcall(json.decode,raw);if not ok or type(data)~='table' then return nil,'invalid JSON' end;return data
end
local function main()
 local Touch=require('platform.kindle.touch');local Runner=require('platform.kindle.runner');local Paths=require('platform.kindle.paths');local Display=require('platform.kindle.display_native')
 if args.probe_touch then local t=Touch.new({});local ok,e=t:open(false);if not ok then error(e) end;print(t:description());t:close();return 0 end
 if args.probe_native then local d=Display.new({device=true,fonts=fonts()});assert(d:measure('中文 SoundRing',32)>0);d:close();print('font and framebuffer preflight OK');return 0 end
 if args.probe_display then local w,h=Paths.new({app_dir=appdir}):screen_size(Runner.new({}),assert(args.fbink));print('viewport '..w..'x'..h);return 0 end
 if not os.getenv('KDASH_POWER_RUN') or not os.getenv('KDASH_HTTP_DIR') then error('supervisor environment required') end
 local cfg,e=readjson(args.data_dir..'/soundring-config.json');if not cfg then error('configuration unavailable: '..tostring(e)) end
 local token,te=readjson(args.data_dir..'/soundring-token.json');if not token then error('authorization unavailable: '..tostring(te)) end
 if not cfg.client_id or cfg.client_id=='' or cfg.client_id~=token.client_id then error('Client ID mismatch; reauthorize') end
 assert(storage:mkdir_p(args.data_dir..'/logs'),'cannot create log directory')
 local log=require('core.log').new({path=args.data_dir..'/logs/soundring.log',level='info',echo=false})
 local runner=Runner.new({log=log});local fbink=args.fbink or os.getenv('KDASH_FBINK');local w,h=Paths.new({app_dir=appdir}):screen_size(runner,assert(fbink))
 local display=Display.new({device=true,fonts=fonts(),runner=runner,fbink=fbink,width=w,height=h,log=log,full_refresh_every=24})
 local touch=Touch.new({width=w,height=h,log=log});local http;local power;local covers;local artist_covers
 local function cleanup() if artist_covers then pcall(function()artist_covers:clear()end) end;if covers then pcall(function()covers:clear()end) end;if http then pcall(function()http:cancel_all()end) end;if power then pcall(function()power:release()end)end;pcall(function()touch:close()end);pcall(function()display:close()end)end
 local ok,res=xpcall(function()
  local Clock=require('platform.kindle.clock');local clock=Clock.new()
  require('soundring.splash').draw(display);clock:sleep_ms(800)
  local yes,err=touch:open();if not yes then error(err) end
  power=require('platform.kindle.power').new({runner=runner,log=log,events_path=os.getenv('KDASH_POWER_EVENTS')})
  local button,pe=power:open_button();if not button then error(pe) end
  local cacert;for _,p in ipairs({'/etc/ssl/certs/ca-certificates.crt','/etc/ssl/certs/ca-bundle.crt','/etc/ssl/cert.pem'})do if util.path_exists(p) then cacert=p;break end end
  http=require('services.http').new({runner=runner,storage=storage,dir=os.getenv('KDASH_HTTP_DIR'),log=log,now=function()return clock:now()end,curl=os.getenv('KDASH_CURL') or 'curl',cacert=cacert})
  local spotify=require('soundring.spotify').new({http=http,json=json,client_id=cfg.client_id,token=token,now=function()return clock:now()end,save_token=function(v)return storage:write_atomic(args.data_dir..'/soundring-token.json',json.encode(v))end})
  local choices=require('soundring.choice_store').new({storage=storage,json=json,path=args.data_dir..'/lyric-choices.json'})
  local artist_store=require('soundring.artist_store').new({storage=storage,json=json,dir=args.data_dir..'/artists'})
  local lyric_cache=require('soundring.lyrics_cache').new({storage=storage,json=json,dir=args.data_dir..'/lyrics-cache'})
  covers=require('soundring.covers').new({http=http,storage=storage,runner=runner,dir=os.getenv('KDASH_HTTP_DIR'),converter=assert(os.getenv('SOUNDRING_COVERCONV')),now=function()return clock:now()end})
  local app=require('soundring.app').new({spotify=spotify,http=http,json=json,log=log,covers=covers,load_artist=function(id)return artist_store:load(id)end,artist_display_name=function(id,name)return artist_store:display_name(id,name)end,save_artist_alias=function(id,name,alias,source,source_id)local ok=artist_store:save_alias(id,name,alias);if ok and source=='netease' and type(source_id)=='string' and source_id:match('^%d+$') and #source_id<=20 then artist_store:save(id,{netease_id=source_id}) end;return ok end,now=function()return clock:now()end,lyrics_source=cfg.lyrics_source,load_local=function(track) if not track.id or not track.id:match('^[%w]+$') then return nil end;return storage:read(args.data_dir..'/lyrics/'..track.id..'.lrc',524288) end,load_choice=function(id)return choices:load(id)end,save_choice=function(id,c)return choices:save(id,c)end,load_cache=function(id,c)return lyric_cache:load(id,c)end,save_cache=function(id,result,c)return lyric_cache:save(id,result,c)end})
  app.state.default_artist_path=appdir..'/assets/default-artist.gray'
  artist_covers=require('soundring.covers').new({http=http,storage=storage,runner=runner,dir=os.getenv('KDASH_HTTP_DIR'),converter=assert(os.getenv('SOUNDRING_COVERCONV')),prefix='artist',now=function()return clock:now()end})
  app.artist_info=require('soundring.artist_info').new({spotify=spotify,http=http,json=json,store=artist_store,storage=storage,covers=artist_covers,changed=function(items,index)app.state.artists=items;app.state.artist_index=index;app:changed()end})
  local device=require('platform.kindle.device').new({storage=storage,runner=runner,log=log})
  local runtime=require('soundring.runtime');return runtime.run({app=app,covers=covers,artist_covers=artist_covers,display=display,touch=touch,http=http,clock=clock,power=power,network_status=function()local w=device:wifi();local b=device:battery();local level=b and b.level and tostring(math.floor(b.level))..'%' or '--%';return (w.connected and 'Wi-Fi' or '离线')..' '..level end,session_limit=tonumber(os.getenv('SOUNDRING_SESSION_LIMIT')) or 0,heartbeat=function(sleeping)local run=os.getenv('KDASH_POWER_RUN');if run then if sleeping then storage:write(run..'/sleeping','1\n') else storage:remove(run..'/sleeping') end;storage:write_atomic(run..'/heartbeat',tostring(os.time())..'\n') end end,interval=math.max(5,math.min(120,tonumber(cfg.refresh_seconds) or 5))})
 end,debug.traceback)
 cleanup();if not ok then error(res) end;if not res then error('runtime failed') end;return 0
end
local ok,result=xpcall(main,debug.traceback);if not ok then io.stderr:write('SoundRing error: '..tostring(result)..'\n');os.exit(1)end;os.exit(result)
