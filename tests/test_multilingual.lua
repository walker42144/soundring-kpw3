local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local lyrics=require('soundring.lyrics');local lines=lyrics.with_translation('[00:01.00]Hello world\n[00:05.00]Second line','[00:01.20]你好世界\n[00:05.00]第二行');assert(lines[1].translation=='你好世界' and lines[2].translation=='第二行')
local pages=lyrics.pages(lines,100,function(_,line)return line.translation and 40 or 20 end);assert(pages and #pages==1)
local d={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end
local view=require('soundring.view');local zones=assert(view.render(d,{page='now',lyrics_visible=true,lyric_lines=lines},true));local refresh=0;for _,z in ipairs(zones)do if z.name=='refresh' then refresh=refresh+1 end end;assert(refresh==1)
zones=assert(view.render(d,{page='playlist_items',items={},status='playlist_forbidden'},true));local back=0;for _,z in ipairs(zones)do if z.name=='playlist_back' then back=back+1 end end;assert(back==1)
print('Translations, balanced lyric paging, playlist back and refresh hit targets passed')

local han=lyrics.with_translation('[00:01]青空未来希望\n[00:05]永遠の夢','[00:01]蓝天未来希望\n[00:05]永远的梦');assert(han[1].translation=='蓝天未来希望')
local zh=lyrics.with_translation('[00:01]聽媽媽的話\n[00:05]別讓她受傷','[00:01]听妈妈的话\n[00:05]别让她受伤');assert(not zh[1].translation)
print('Han-only Japanese translation retained; identical simplified Chinese suppressed')
