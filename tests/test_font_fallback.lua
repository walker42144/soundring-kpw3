local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local base=root..'/assets/fonts/';local korean=base..'NotoSansKR-VF.ttf'
local f=require('platform.kindle.freetype').new({library=assert(arg[1]),cjk=base..'MiSans-Regular.ttf',fallback=base..'SourceHanSansCN-Medium.ttf',international=base..'NotoSans-Regular.ttf',latin=base..'KumbhSans-500.ttf',display=base..'KumbhSans-600.ttf',korean=korean})
assert(f.korean,'Korean font could not be opened');local actual=f:glyph(0xac00,28);local reference=f:glyph(0xac00,28,korean);assert(actual.advance>0 and actual.w>0 and actual.pixels==reference.pixels,'Hangul did not use Korean font')
local unsupported=f:glyph(0x1f600,28);assert(unsupported.advance>0,'unsupported emoji is zero width');f:close();print('FreeType: Korean fallback renders, unsupported glyph has visible-width replacement')
