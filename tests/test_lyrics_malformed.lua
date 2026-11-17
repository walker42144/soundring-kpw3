local lyrics=require('soundring.lyrics')
local x=lyrics.parse('[00:01][00:02broken\n[00:03]good\n[00:04][00:05]both')
assert(#x==3 and x[1].text=='good' and x[2].text=='both' and x[3].text=='both')
assert(#lyrics.parse(string.rep('x',524289))==0)
assert(#lyrics.parse('[00:01]'..string.rep('x',9000))==0)
local many={};for i=1,5000 do many[#many+1]='[00:01]line' end
assert(#lyrics.parse(table.concat(many,'\n'))==4096)
local repeated='[00:01]'..string.rep('[00:01]',140)..'x'
assert(#lyrics.parse(repeated)==0)
local both=lyrics.with_translation('[00:03]hello','[00:02][00:26.295broken\n[00:03]你好')
assert(#both==1 and both[1].translation=='你好')
print('lyric parser malformed tags, limits, translation passed')
