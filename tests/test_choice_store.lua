local root=arg[0]:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.';package.path=root..'/?.lua;'..package.path
local j=require('core.json');local files={};local st={read=function(_,p)return files[p]end,write_atomic=function(_,p,s)files[p]=s;return true end};local db=require('soundring.choice_store').new({storage=st,json=j,path='state.json'})
assert(db:save('spotify123',{source='qq',id='abc123'}));assert(db:load('spotify123').id=='abc123')
assert(not db:save('../wrong',{source='qq',id='abc'}));assert(not db:save('good',{source='netease',id='abc'}));files['state.json']='corrupt';local ok,why=db:save('good',{source='qq',id='abc'});assert(not ok and why=='invalid_choice_store' and files['state.json']=='corrupt')
print('Choice store: atomic persistence, validation, corrupt data preservation passed')
