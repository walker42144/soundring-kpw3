-- Timed LRC parsing. No network access or inferred Spotify lyrics.
local M = {}
function M.parse(text)
    local out, sequence = {}, 0
    if type(text) ~= 'string' or #text > 524288 then return out end
    local line_count = 0
    for line in (text .. '\n'):gmatch('(.-)\r?\n') do
        line_count = line_count + 1
        if line_count > 4096 or sequence >= 4096 then break end
        local body, malformed, tags = line:gsub('^%s*(%b[])', '', 1), #line > 8192, 0
        while not malformed and body:match('^%s*%[%d+:%d') do
            local next_body, count = body:gsub('^%s*(%b[])', '', 1)
            tags = tags + 1
            if count == 0 or tags > 128 then malformed = true else body = next_body end
        end
        body = body:match('^%s*(.-)%s*$') or ''
        if not malformed and body ~= '' then
            for minute, sec in line:gmatch('%[(%d+):(%d+%.?%d*)%]') do
                local value = tonumber(sec)
                if sequence >= 4096 then break end
                if value and value < 60 and tonumber(minute) and tonumber(minute) < 100000 then
                    sequence = sequence + 1
                    out[#out+1] = {ms = math.floor((tonumber(minute)*60+value)*1000+0.5), text = body, order = sequence}
                end
            end
        end
    end
    table.sort(out,function(a,b) if a.ms == b.ms then return a.order < b.order end return a.ms < b.ms end)
    return out
end
function M.is_chinese(lines)
 local han,other=0,0
 for i,line in ipairs(lines or {}) do
  if i>12 then break end
  for _,ch in ipairs(require('core.util').utf8_codepoints(line.text or '')) do
   local c=ch.cp
   if (c>=0x3040 and c<=0x30ff) or (c>=0xac00 and c<=0xd7af) or (c>=0x1100 and c<=0x11ff) then return false end
   if c>=0x3400 and c<=0x9fff then han=han+1 elseif (c>=65 and c<=90) or (c>=97 and c<=122) then other=other+1 end
  end
 end
 return han>=4 and han>=other*3
end
function M.with_translation(original, translated)
 local lines=M.parse(original);local translations=M.parse(translated);local j=1
 -- Infer a uniform offset only from multiple isolated, consistent anchors.
 -- A single pair or densely spaced lyrics are insufficient evidence.
 local offsets={};local last=0;local first_possible=1
 for i,line in ipairs(lines) do
  while translations[first_possible] and translations[first_possible].ms < line.ms-1500 do first_possible=first_possible+1 end
  local before=lines[i-1];local after=lines[i+1]
  if (not before or line.ms-before.ms>3000) and (not after or after.ms-line.ms>3000) then
   local best,dist
   for k=math.max(last+1,first_possible),#translations do local delta=translations[k].ms-line.ms;local d=math.abs(delta);if delta>1500 then break end;if d<=1500 and (not dist or d<dist) then best=k;dist=d end end
   if best then offsets[#offsets+1]=translations[best].ms-line.ms;last=best end
  end
 end
 local offset=0
 if #offsets>=3 then table.sort(offsets);local median=offsets[math.floor((#offsets+1)/2)];local count=0;for _,v in ipairs(offsets) do if math.abs(v-median)<=200 then count=count+1 end end;if count>=3 and count>=math.ceil(#offsets*.75) then offset=median end end
 for _,line in ipairs(lines) do
  while translations[j] and translations[j].ms < line.ms+offset-500 do j=j+1 end
  if translations[j] and math.abs(translations[j].ms-line.ms-offset)<=500 then local t=translations[j].text;local normalize=require('soundring.lyrics_online').simplified;if normalize(t):gsub('%s+','')~=normalize(line.text):gsub('%s+','') then line.translation=t end;j=j+1 end
 end
 return lines
end
-- Build full-line pages using a caller-supplied measured height and column capacity.
function M.pages(lines, capacity, measure)
    assert(type(measure)=='function' and capacity > 0)
    local pages, cols, used = {}, {{},{}}, 0
    local col = 1
    for _, line in ipairs(lines) do
        local h = measure(line.text,line)
        if type(h)~='number' or h<=0 or h>capacity then return nil, 'line does not fit' end
        if used+h>capacity and #cols[col]>0 then
            if col==1 then col=2 else pages[#pages+1]=cols;cols={{},{}};col=1 end
            used=0
        end
        cols[col][#cols[col]+1]=line;used=used+h
    end
    if #cols[1]>0 or #cols[2]>0 then pages[#pages+1]=cols end
    -- Keep reading order while balancing the height of the two columns.
    for _,page in ipairs(pages) do
        local all={};for _,column in ipairs(page) do for _,line in ipairs(column) do all[#all+1]=line end end
        if #all>1 then
            local heights,total={},0;for i,line in ipairs(all) do heights[i]=measure(line.text,line);total=total+heights[i] end
            local left,best,bestdiff=0,nil,math.huge
            for i=1,#all-1 do left=left+heights[i];local right=total-left
                if left<=capacity and right<=capacity and math.abs(left-right)<bestdiff then best,bestdiff=i,math.abs(left-right) end
            end
            if best then page[1],page[2]={},{};for i,line in ipairs(all) do local col=i<=best and 1 or 2;page[col][#page[col]+1]=line end end
        end
    end
    return pages
end
function M.page_at(pages, elapsed_ms)
    local found=1
    for i,page in ipairs(pages) do
        local first=page[1][1] or page[2][1]
        if first and first.ms <= elapsed_ms then found=i else break end
    end
    return #pages>0 and found or nil
end
return M
