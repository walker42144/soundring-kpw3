local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local view=require('soundring.view');local d={width=1072,height=1448,count=0};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end;function d:measure(s,size)self.count=self.count+1;return #s*size*.48 end
local lines={};for i=1,80 do lines[i]={ms=i*1000,text='This is a synthetic lyric line '..i} end
local s={page='now',lyrics_visible=true,lyric_lines=lines,track={},duration_ms=180000};assert(view.render(d,s));local first=d.count;d.count=0;assert(view.render(d,s));local second=d.count;assert(second<first/3,'lyric pagination was not cached');s.lyric_lines={{ms=1000,text='A different lyric'}};d.count=0;assert(view.render(d,s));assert(s._lyric_pages.lines==s.lyric_lines)
print('Lyrics pagination: repeat rendering uses cache; new content invalidates it')
