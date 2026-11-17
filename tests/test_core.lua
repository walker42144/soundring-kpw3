local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local p=require('soundring.playback')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local b=p.minute_bars(285000,120000);eq(#b,5);eq(b[1],true);eq(b[2],true);eq(b[3],false)
eq(p.minute_bars(285000,285000)[5],true);eq(#p.minute_bars(420000,0),7);eq(p.seek_for_bar(7,420000),360000);eq(p.seek_for_bar(8,420000),nil)
local l=require('soundring.lyrics');local x=l.parse('[00:01.50][00:05.00] hello world\n[00:03.00] 再见\n[ar:artist]\n')
eq(#x,3);eq(x[1].ms,1500);eq(x[2].text,'再见');eq(x[3].text,'hello world')
local pages=assert(l.pages(x,20,function()return 10 end));eq(#pages,1);eq(#pages[1][1],1);eq(#pages[1][2],2);eq(l.page_at(pages,4000),1)
local no,err=l.pages(x,5,function()return 10 end);eq(no,nil);eq(err,'line does not fit')
local d={width=1072,height=1448,calls={}};for _,n in ipairs({'begin_frame','circle','line','flush'}) do d[n]=function(self,...) self.calls[#self.calls+1]=n end end
require('soundring.splash').draw(d);eq(d.calls[1],'begin_frame');eq(d.calls[#d.calls],'flush')
print('SoundRing core: progress, LRC parsing/pagination, splash drawing passed')
local view=require('soundring.view')
local l=view.layout(1072,1448);assert(l.center_x==536 and l.margin==37 and l.transport_y<l.action_y and l.action_y<l.bottom_y)
local d={width=1072,height=1448,calls={}};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line','flush'}) do d[n]=function(self,...) self.calls[#self.calls+1]=n; return true end end
assert(view.render(d,{page='now',duration_ms=420000,progress_ms=60000,playing=true}));assert(#d.calls>12)
print('SoundRing view: layout and display-call smoke test passed')



