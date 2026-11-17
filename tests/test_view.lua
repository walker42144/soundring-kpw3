local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local view=require('soundring.view');local d={width=1072,height=1448};for _,n in ipairs({'begin_frame','text','fill','hline','circle','line'})do d[n]=function()end end;function d:flush()return true end
local state={page='lyrics_search',lyrics={status='choose',candidates={}}};for i=1,9 do state.lyrics.candidates[i]={source='qq',id=tostring(i),name='Song '..i,artists={'Artist'},duration=180} end
local zones=assert(view.render(d,state,true));local action,value=view.hit(zones,60,240);assert(action=='lyrics_choose' and value==1)
action,value=view.hit(zones,500,165);assert(action=='lyrics_search' and value=='netease')
state.lyrics_offset=6;zones=assert(view.render(d,state));action,value=view.hit(zones,60,240);assert(action=='lyrics_choose' and value==7)
action=view.hit(zones,530,1310);assert(action=='lyrics_back')
state={page='now',track={name='Song',artist='Artist'},duration_ms=420000,progress_ms=60000};zones=assert(view.render(d,state));action=view.hit(zones,536,1200);assert(action=='play' or action=='lyrics' or action==nil)
print('View: lyrics source selection, candidate hit targets and pagination passed')

state={page='lyrics_search',lyrics={status='choose',candidates={}}};zones=assert(view.render(d,state));action=view.hit(zones,800,165);assert(action=='lyrics_keyword')
state={page='lyrics_input',search_text='TEST'};zones=assert(view.render(d,state));action,value=view.hit(zones,70,310);assert(action=='search_key' and value=='1')
print('View: manual keyword search entry and keyboard targets passed')
state={page='now',duration_ms=120*60000,progress_ms=1000};zones=assert(view.render(d,state));local layout=view.layout(d.width,d.height);local seekcount=0
for _,z in ipairs(zones) do if z.name=='seek' then seekcount=seekcount+1;assert(z.x<layout.margin+60 and z.y+z.h<=layout.transport_y+57) end end
assert(seekcount==0);print('View: progress indicators do not create seek targets')

local images={};function d:image_gray(path,x,y,w,h,radius)images[#images+1]={path=path,radius=radius};return path=='fallback.gray' or path=='real.gray' end
function d:rounded_box() error('image should be available') end
state={page='now',track={name='Song',artist='Artist'},artists={{name='Artist'}},artist_index=1,default_artist_path='fallback.gray',duration_ms=120000};assert(view.render(d,state));assert(images[1].path=='fallback.gray' and images[1].radius==16)
images={};state.artists[1].image_path='real.gray';assert(view.render(d,state));assert(#images==1 and images[1].path=='real.gray')
images={};state.artists[1].image_path='broken.gray';assert(view.render(d,state));assert(#images==2 and images[2].path=='fallback.gray')
print('View: missing or corrupt artist image uses rounded fallback; real image remains preferred')

state={page='search_input',search_text=''};zones=assert(view.render(d,state));local bykey={};for _,z in ipairs(zones)do if z.name=='search_key' and z.value~=' ' then bykey[z.value]=z end end
for row,letters in ipairs({'1234567890','QWERTYUIOP','ASDFGHJKL','ZXCVBNM'}) do for i=1,#letters do local z=assert(bykey[letters:sub(i,i)]);assert(z.y==290+(row-1)*100);if i>1 then assert(z.x>bykey[letters:sub(i-1,i-1)].x) end end end
assert(view.hit(zones,350,720)=='search_left');assert(view.hit(zones,650,720)=='search_right')
local drawn={};function d:text(item)drawn[#drawn+1]=item.text end
state.search_text='ABCD';state.search_cursor=2;assert(view.render(d,state));local found=false;for _,v in ipairs(drawn) do if v=='AB｜CD' then found=true end end;assert(found)
print('Keyboard: QWERTY rows, cursor controls and caret display passed')
