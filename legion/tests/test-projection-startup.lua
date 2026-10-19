local profile=assert(arg[1])
local module=dofile(profile .. '/.config/hypr/scripts/projection-startup.lua')
local path=os.tmpname()
local f=assert(io.open(path,'w'))
f:write('hl.monitor({output="desc:panel",disabled=true})\nhl.monitor({output="DP-3",mode="preferred",scale=1})')
f:close()
local rules={}
local api={monitor=function(r)rules[#rules+1]=r end,workspace_rule=function()end,config=function()end}
local ok=module.load(api,path,function(name)return name=='eDP-1' end)
assert(ok and rules[1].output=='eDP-1' and rules[1].disabled==false and rules[1].scale==1.25)
rules={}
assert(module.load(api,path,function(name)return name=='eDP-1' or name=='DP-3' end))
assert(rules[1].output=='desc:panel' and rules[1].disabled==true)
assert(rules[2].disabled==false and rules[2].mirror=='')
os.remove(path)
print('PASS disconnected external-only description guard, alternate DP port and explicit reset fields')
