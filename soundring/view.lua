-- KPW3 view and touch regions, share geometry for input and drawing.
local Playback=require('soundring.playback');local Lyrics=require('soundring.lyrics')
local M={}
function M.layout(w,h)
 local margin=math.floor(w*.035);local footer=64;local action_y=h-footer-90;local transport_y=action_y-100
 return {w=w,h=h,margin=margin,footer=footer,transport_y=transport_y,action_y=action_y,bottom_y=h-footer,center_x=math.floor(w/2)}
end
local function clip(d,text,width,size)
 text=tostring(text or '');if not d.measure then return text end
 if d:measure(text,size)<=width then return text end
 local chars={};for c in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do chars[#chars+1]=c end
 while #chars>0 do table.remove(chars);local s=table.concat(chars)..'…';if d:measure(s,size)<=width then return s end end
 return ''
end
local function text(d,x,y,w,size,value,align)
 d:text({x=x,y=y,w=w,size=size,text=clip(d,value,w,size),align=align or 'left',color='ink',bg='paper'})
end
local function wrap(d,value,width,size)
 local out,line={},''
 for c in tostring(value or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
  local nextline=line..c
  if line~='' and d.measure and d:measure(nextline,size)>width then
   local head,word=line:match('^(.*)%s+(%S+)$')
   if head and head~='' and word and d:measure(word..c,size)<=width then out[#out+1]=head;line=word..c
   else out[#out+1]=line;line=c end
  else line=nextline end
 end
 if line~='' then out[#out+1]=line end
 return out
end
local function transport_icon(d,kind,cx,cy)
 local col='ink';local function line(x1,y1,x2,y2)d:line(cx+x1,cy+y1,cx+x2,cy+y2,col,4)end
 if kind=='pause' then line(-7,-15,-7,15);line(7,-15,7,15)
 elseif kind=='play' then line(-9,-16,13,0);line(13,0,-9,16);line(-9,16,-9,-16)
 elseif kind=='previous' then line(-15,-16,-15,16);line(13,-15,-9,0);line(-9,0,13,15);line(13,15,13,-15)
 else line(15,-16,15,16);line(-13,-15,9,0);line(9,0,-13,15);line(-13,15,-13,-15) end
end
local function action_icon(d,kind,cx,cy,on)
 if on then d:circle(cx,cy,27,'ink',true) end
 local col=on and 'paper' or 'ink';local function line(x1,y1,x2,y2)d:line(cx+x1,cy+y1,cx+x2,cy+y2,col,3)end
 if kind=='shuffle' then line(-15,-10,-8,-10);line(-8,-10,8,10);line(8,10,15,10);line(10,5,15,10);line(15,10,10,15);line(-15,10,-8,10);line(-8,10,8,-10);line(8,-10,15,-10);line(10,-15,15,-10);line(15,-10,10,-5)
 elseif kind=='repeat' then line(-14,-7,11,-7);line(11,-7,7,-12);line(11,-7,7,-2);line(14,7,-11,7);line(-11,7,-7,2);line(-11,7,-7,12)
 elseif kind=='refresh' then line(-13,-5,-8,-12);line(-8,-12,3,-15);line(3,-15,12,-9);line(12,-9,14,-3);line(14,-3,8,-6);line(14,-3,17,-9);line(13,5,8,12);line(8,12,-3,15);line(-3,15,-12,9);line(-12,9,-14,3);line(-14,3,-8,6);line(-14,3,-17,9)
 elseif kind=='like' then line(0,14,-13,1);line(-13,1,-13,-7);line(-13,-7,-8,-12);line(-8,-12,-3,-12);line(-3,-12,0,-7);line(0,-7,3,-12);line(3,-12,8,-12);line(8,-12,13,-7);line(13,-7,13,1);line(13,1,0,14)
 else line(-13,-11,13,-11);line(-13,-3,13,-3);line(-13,5,13,5);line(-13,13,5,13) end
end
function M.render(d,state,full)
 local w,h=d.width,d.height;local l=M.layout(w,h);local m=l.margin;local zones={}
 local function zone(name,x,y,ww,hh,value)zones[#zones+1]={name=name,x=x,y=y,w=ww,h=hh,value=value}end
 d:begin_frame(true)
 d:circle(m+14,34,13,'ink',false,2);d:circle(m+14,34,3,'ink',true);d:line(m+8,26,m+6,34,'ink',2);d:line(m+6,34,m+8,42,'ink',2);d:line(m+20,26,m+22,34,'ink',2);d:line(m+22,34,m+20,42,'ink',2);text(d,m+36,20,w*.26,25,'SoundRing');text(d,w*.33,20,w*.34,24,state.device or '无播放设备','center')
 text(d,w*.70,20,w*.26,18,(state.wifi_label or 'Wi-Fi --%')..'  退出', 'right');zone('exit',w*.89,0,w*.11,75)
 local s=state;local t=s.track or {}
 local errors={request_failed='网络或授权异常，请重试',network_error='网络连接失败，请检查 Wi-Fi',device_unavailable='播放设备不可用',token_refresh_failed='授权已失效，请在电脑重新授权',authorization_required='请先在电脑完成授权',token_expired='授权需要刷新，请稍后重试',token_save_failed='无法保存授权，请检查存储空间',queue_full='请求繁忙，请稍后重试',timeout='网络超时，请重试',cancelled='请求已取消',paused='网络请求已暂停',invalid_track='该条目暂不支持播放',rate_limited='Spotify 请求频繁，请稍后重试'}
 if s.trial_notice then text(d,m,72,w-2*m,19,'测试版将在 '..s.trial_notice..' 分钟后自动退出','center') end
 if s.page=='lyrics_search' then
  text(d,m,100,w-2*m,35,'选择正确歌词')
  text(d,m,160,w*.28,25,'QQ 音乐');text(d,w*.36,160,w*.27,25,'网易云');text(d,w*.66,160,w*.28,25,'改关键词','right')
  zone('lyrics_search',m,145,w*.28,65,'qq');zone('lyrics_search',w*.35,145,w*.27,65,'netease');zone('lyrics_keyword',w*.65,145,w*.30,65)
  local ls=s.lyrics or {};local list=ls.candidates or {};local offset=s.lyrics_offset or 0
  if ls.status=='searching' or ls.status=='loading_choice' then text(d,m,240,w-2*m,27,'正在查询…')
  elseif ls.status=='search_error' then text(d,m,240,w-2*m,26,'获取失败，请重试或选择其他来源')
  elseif #list==0 then text(d,m,240,w-2*m,26,'没有找到结果，请尝试其他来源')
  else
   if ls.status=='choice_error' then text(d,m,205,w-2*m,19,'获取失败，请重试或选择其他结果') end
   for row=1,6 do
    local index=offset+row;local c=list[index];if not c then break end;local y=230+(row-1)*135
    text(d,m,y,w-2*m,30,c.name);local a=table.concat(c.artists or {},' / ');local sec=math.floor(c.duration or 0)
    text(d,m,y+43,w-2*m,22,a..'   '..(c.album or '')..'   '..string.format('%d:%02d',math.floor(sec/60),sec%60))
    d:hline(m,y+111,w-2*m,1,'gray4');zone('lyrics_choose',m,y-5,w-2*m,116,index)
   end
  end
  text(d,m,h-145,w*.25,24,'上一页');text(d,w*.37,h-145,w*.26,24,'返回','center');text(d,w*.7,h-145,w*.25,24,'下一页','right')
  zone('lyrics_prev',m,h-165,w*.25,70);zone('lyrics_back',w*.35,h-165,w*.3,70);zone('lyrics_next',w*.7,h-165,w*.25,70)
 elseif s.page=='search_input' or s.page=='lyrics_input' then
  local input=s.search_text or '';local pos=math.max(0,math.min(#input,s.search_cursor or #input));local before=input:sub(1,pos);local after=input:sub(pos+1)
  if d.measure then while before~='' and d:measure(before..'｜',28)>w-2*m do before=before:gsub('^[%z\1-\127\194-\244][\128-\191]*','',1) end end
  text(d,m,100,w-2*m,36,s.page=='lyrics_input' and '搜索歌词（英文或拼音）' or '搜索 Spotify（英文或拼音）');text(d,m,175,w-2*m,28,before..'｜'..after);d:hline(m,225,w-2*m,2,'ink')
  local rows={'1234567890','QWERTYUIOP','ASDFGHJKL','ZXCVBNM'};local y=300
  for _,row in ipairs(rows) do local step=(w-2*m)/10;local inset=(10-#row)*step/2;for i=1,#row do local x=m+inset+(i-1)*step;text(d,x,y,step,30,row:sub(i,i),'center');zone('search_key',x,y-10,step,75,row:sub(i,i)) end;y=y+100 end
  text(d,w*.27,y+10,w*.20,30,'←','center');text(d,w*.53,y+10,w*.20,30,'→','center')
  zone('search_left',w*.27,y,w*.20,75);zone('search_right',w*.53,y,w*.20,75);y=y+100
  text(d,m,y+10,w*.3,26,'空格','center');text(d,w*.36,y+10,w*.28,26,'删除','center');text(d,w*.68,y+10,w*.27,26,'搜索','center')
  zone('search_key',m,y,w*.3,75,' ');zone('search_delete',w*.35,y,w*.3,75);zone(s.page=='lyrics_input' and 'lyrics_submit' or 'search_submit',w*.67,y,w*.28,75)
 elseif s.page=='now' then
  if s.lyrics_visible then
   local small=86;local covered=s.cover_path and d.image_gray and d:image_gray(s.cover_path,m,92,small,small)
   if not covered then d:fill({x=m,y=92,w=small,h=small},'gray5');d:circle(m+small/2,92+small/2,small*.25,'gray2',false,3) end
   text(d,m+small+24,96,w-2*m-small-24,32,t.name or '未播放');text(d,m+small+24,142,w-2*m-small-24,24,(t.display_artist and t.display_artist~='' and t.display_artist or t.artist) or '')
   d:hline(m,190,w-2*m,1,'gray4');text(d,m,210,w-2*m,24,'歌词')
   local lines=s.lyric_lines or {};local gap=22;local column=(w-2*m-gap)/2;local size=27;local available=l.transport_y-280;local lh=38
   local message=errors[s.status];if message then text(d,m,230,w-2*m,20,message) end
   local pages=Lyrics.pages(lines,available,function(v,line)return math.max(1,#wrap(d,v,column,size))*lh+(line.translation and #wrap(d,line.translation,column,21)*29 or 0) end)
   if pages then
    local chosen=Lyrics.page_at(pages,s.progress_ms or 0) or 1;local nextpage=pages[chosen+1];s.lyric_next_ms=nextpage and ((nextpage[1][1] or nextpage[2][1]).ms) or nil;local p=pages[chosen]
    if p then for col=1,2 do local y=message and 265 or 255;for _,line in ipairs(p[col]) do for _,v in ipairs(wrap(d,line.text,column,size)) do text(d,m+(col-1)*(column+gap),y,column,size,v);y=y+lh end;if line.translation then for _,v in ipairs(wrap(d,line.translation,column,21)) do text(d,m+(col-1)*(column+gap),y,column,21,v);y=y+29 end end end end end
   elseif #lines>0 then text(d,m,260,w-2*m,25,'歌词过长，无法完整显示') end
   if s.lyrics and s.lyrics.warning=='choice_not_saved' then text(d,m,235,w-2*m,20,'歌词已显示，但选择未能保存') end
   if #lines==0 then text(d,m,260,w-2*m,25,'暂无同步歌词');text(d,m,300,w-2*m,23,'点击此处选择歌词，可尝试仅输入歌名');zone('lyrics_search',m,240,w-2*m,110,'qq') end
   zone('lyrics_search',w-210,195,180,60,'qq');text(d,w-210,210,180,22,'选择歌词','right')
  else
   s.lyric_next_ms=nil
   local art=math.min(w*.68,600);local ax=(w-art)/2;local ay=145
   local covered=s.cover_path and d.image_gray and d:image_gray(s.cover_path,ax,ay,art,art)
   if not covered then d:fill({x=ax,y=ay,w=art,h=art},'gray5');d:circle(w/2,ay+art/2,art*.30,'gray2',false,5);d:circle(w/2,ay+art/2,art*.08,'ink',true) end
   text(d,m,ay+art+45,w-2*m,40,t.name or '未播放');text(d,m,ay+art+100,w-2*m,28,(t.display_artist and t.display_artist~='' and t.display_artist or t.artist) or '')
   local messages={play_not_confirmed='播放设备未确认切歌，请重试',loading='正在连接 Spotify…',no_playback='请先在其他设备播放 Spotify',request_failed='网络或授权异常，请检查后重试',network_error='网络连接失败，请检查 Wi-Fi',device_unavailable='播放设备不可用，请检查 Spotify',token_refresh_failed='授权已失效，请在电脑重新授权',authorization_required='请先在电脑完成授权',token_expired='授权需要刷新，请稍后重试',token_save_failed='无法保存授权，请检查存储空间',queue_full='请求繁忙，请稍后重试',timeout='网络超时，请重试',cancelled='请求已取消',paused='网络请求已暂停',invalid_track='该条目暂不支持播放',rate_limited='Spotify 请求过于频繁，请稍后重试'}
   if messages[s.status] then text(d,m,ay+art+150,w-2*m,23,messages[s.status]) elseif s.status and s.status~='ready' then text(d,m,ay+art+150,w-2*m,23,'操作失败，请稍后重试') end
   local info=state.artists or {};local selected=info[state.artist_index or 1];local top=ay+art+158;local bottom=l.transport_y-25
   if selected and bottom>top+150 then
    local line_y=top;local x0=w/6;local width=w*2/3
    d:hline(x0+width*.2,line_y,width*.6,2,'gray4');d:hline(x0+width*.1,line_y,width*.1,1,'gray4');d:hline(x0+width*.8,line_y,width*.1,1,'gray4')
    local py=top+22;local side=math.min(160,bottom-py);local px=m+12
    local has=selected.image_path and d.image_gray and d:image_gray(selected.image_path,px,py,side,side,16)
    if not has and state.default_artist_path and d.image_gray then has=d:image_gray(state.default_artist_path,px,py,side,side,16) end
    if not has then d:rounded_box({x=px,y=py,w=side,h=side},16,'gray5') end
    local tx=px+side+22;local tw=w-m-tx-120
    text(d,tx,py,tw,25,selected.display_name or selected.name or '')
    local bio=selected.bio and selected.bio~='' and selected.bio or (selected.cached and '暂无艺人介绍' or '正在获取艺人介绍…')
    local rows=wrap(d,bio,tw,22);for row=1,math.min(3,#rows)do text(d,tx,py+38+(row-1)*29,tw,22,rows[row])end
    if #info>1 then local right=w-m;local cy=py+56;d:line(right-89,cy,right-100,cy+10,'ink',3);d:line(right-100,cy+10,right-89,cy+20,'ink',3);d:line(right-43,cy,right-32,cy+10,'ink',3);d:line(right-32,cy+10,right-43,cy+20,'ink',3);zone('artist_previous',right-115,py+20,55,90);zone('artist_next',right-60,py+20,55,90) end
    local nextname=state.next_track or (state.next_status=='loading' and '正在读取队列' or state.next_status=='unavailable' and '队列暂不可用' or '暂无下一首');local ny=bottom-27;text(d,tx+35,ny,w-m-tx-35,22,'»  '..nextname,'center')
   end

  end
  local bars,bar_error=Playback.minute_bars(s.duration_ms,s.progress_ms);if bar_error then text(d,m,l.transport_y,120,19,'时长过长') end;local stride=math.max(1,math.ceil(#bars/21));local count=math.ceil(#bars/stride);local rows=math.max(5,math.ceil(count/3));local step=math.min(11,56/rows);local bh=math.max(1,math.min(7,step*.7))
  for i=1,count do local col=math.floor((i-1)/rows);local row=(i-1)%rows;local x=m+col*20;local y=l.transport_y+row*step;local idx=math.min(#bars,i*stride);d:fill({x=x,y=y,w=10,h=bh},bars[idx] and 'ink' or 'gray4') end
  local dur=math.floor((s.duration_ms or 0)/1000);text(d,m,l.transport_y+65,110,20,string.format('%d:%02d',math.floor(dur/60),dur%60))
  local cx=l.center_x;local ty=l.transport_y+40
  transport_icon(d,'previous',cx-140,ty);transport_icon(d,s.playing and 'pause' or 'play',cx,ty);transport_icon(d,'next',cx+140,ty)
  zone('previous',cx-190,ty-40,100,80);zone('play',cx-50,ty-40,100,80);zone('next',cx+90,ty-40,100,80)
  local names={'shuffle','repeat','refresh','like','lyrics'};local selected={s.shuffle,s.repeat_mode and s.repeat_mode~='off',false,s.liked,s.lyrics_visible}
  local span=math.min(w-2*m,640);local x0=(w-span)/2
  for i=1,5 do local x=x0+(i-.5)*span/5;action_icon(d,names[i],x,l.action_y+27,selected[i]);zone(names[i],x-span/10,l.action_y-10,span/5,74) end
 else
  local title=({devices='播放设备',playlists='歌单',playlist_items='歌曲',search='搜索'})[s.page] or '列表';text(d,m+(s.page=='playlist_items' and 110 or 0),100,w-2*m,36,title);if s.page=='playlist_items' then text(d,m,104,100,26,'‹ 返回');zone('playlist_back',m,88,105,75) end;if s.page=='playlist_items' then local shown=math.min(10,math.max(0,#(s.items or {})-(s.list_offset or 0)));local count=s.list_total and tostring(s.list_total) or '—';text(d,w*.52,112,w*.43,21,'共 '..count..' 首 · 本页 '..shown..' 首','right') end
  if s.page=='devices' and type(s.volume)=='number' then text(d,m,150,w-2*m,24,'音量 −       '..s.volume..'%       +','center');zone('volume',w*.20,135,w*.23,65,-5);zone('volume',w*.57,135,w*.23,65,5)
  elseif s.status=='loading' then text(d,m,150,w-2*m,24,'正在加载…') elseif s.status=='invalid_track' then text(d,m,150,w-2*m,24,'该条目暂不支持播放') elseif s.status=='queue_full' then text(d,m,150,w-2*m,24,'请求繁忙，请稍后重试') elseif s.status=='playlist_forbidden' then text(d,m,150,w-2*m,24,'Spotify 限制查看此歌单，请在 Spotify 打开') elseif s.status~='ready' then text(d,m,150,w-2*m,24,'加载失败，请检查网络和授权') elseif #(s.items or {})==0 then text(d,m,150,w-2*m,24,'没有可显示的项目') end
  for i=1,math.min(s.page=='devices' and 8 or 10,math.max(0,#(s.items or {})-(s.list_offset or 0))) do local item=s.items[(s.list_offset or 0)+i];local itemtrack=type(item)=='table' and (item.item or item.track or item) or {};if type(itemtrack)~='table' then itemtrack={} end;local y=(s.page=='devices' and 230 or 190)+(i-1)*110;local count=s.page=='playlists' and type(item)=='table' and ((type(item.items)=='table' and item.items.total) or (type(item.tracks)=='table' and item.tracks.total)) or nil;text(d,m,y,w-2*m-(s.page=='playlists' and 150 or 0),30,itemtrack.name or '');if s.page=='playlists' then text(d,w-m-150,y+4,150,21,(count and tostring(count) or '—')..' 首','right') end;d:hline(m,y+85,w-2*m,1,'gray4');local action=s.page=='devices' and 'transfer' or s.page=='playlists' and 'playlist_items' or 'play_uri';local value=action=='play_uri' and itemtrack.uri or (type(item)=='table' and item.id);if action=='play_uri' and type(value)=='string' then local context=s.page=='playlist_items' and type(s.playlist_id)=='string' and ('spotify:playlist:'..s.playlist_id) or (type(itemtrack.album)=='table' and itemtrack.album.uri);value={uri=value,context=context} end;if value then zone(action,m,y-8,w-2*m,100,value) end end
  if s.page~='devices' or #(s.items or {})>8 then text(d,m,l.bottom_y-65,w*.3,23,'上一页');text(d,w*.7,l.bottom_y-65,w*.25,23,'下一页','right');zone('list_prev',m,l.bottom_y-80,w*.3,65);zone('list_next',w*.65,l.bottom_y-80,w*.3,65) end
 end
 if s.page~='lyrics_search' then
  d:hline(m,l.bottom_y,w-2*m,1,'gray4');local names={'now','playlists','search_open','devices'};local labels={'播放','歌单','搜索','设备'};local width=(w-2*m)/4
  for i=1,4 do local x=m+(i-1)*width;text(d,x,l.bottom_y+15,width,23,labels[i],'center');zone(names[i],x,l.bottom_y,width,l.footer) end
 end
 local ok=d:flush({full=full==true});if ok==false then return nil,'display_failed' end;return zones
end
function M.hit(zones,x,y)
 for i=#zones,1,-1 do local z=zones[i];if x>=z.x and x<z.x+z.w and y>=z.y and y<z.y+z.h then return z.name,z.value end end
end
return M
