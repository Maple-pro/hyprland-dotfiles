local profile=assert(arg[1], 'pass the Huawei profile directory')
local module_path=profile .. '/.config/hypr/scripts/projection-state.lua'
local passed=0
local function scenario(opts)
 local now,serial=0,0
 local timers,events,moves,restarts={}, {},{},{}
 local files={}; local writes=0; local rescues=0
 local monitors=opts.monitors or {{name='eDP-1',x=0,y=0,width=1920,height=1080,scale=1,transform=0}}
 local path='/runtime/hypr-projection-test'
 if opts.previous then files[path]=opts.previous end
 local io_api={open=function(name,mode)
  if mode=='r' then
   local data=files[name]
   if name:match('/sys/class/drm/card0%-eDP%-1/status') then data='connected' end
   if not data then return nil end
   return {read=function(_,kind)if kind=='*l' then return data:match('[^\n]*') else return data end end,close=function()end}
  end
  files[name]='';writes=writes+1
  return {write=function(_,...)local args={...};for _,s in ipairs(args)do files[name]=files[name]..s end end,close=function()end}
 end}
 local api={get_monitors=function()return monitors end,get_workspaces=function()return opts.workspaces or {} end,
 on=function(n,f)events[n]=f end,
 timer=function(fn,spec)serial=serial+1;timers[#timers+1]={fn=fn,due=now+spec.timeout,spec=spec,id=serial}end,
 exec_cmd=function(cmd)restarts[#restarts+1]=cmd end,
 monitor=function()rescues=rescues+1 end,
 dsp={workspace={move=function(spec)return spec end}},dispatch=function(d)moves[#moves+1]=d end}
 local env=setmetatable({dofile=function(path)
  return dofile((path:gsub('^/home/yangfeng/',profile .. '/')))
 end,io=io_api,os={getenv=function(k)return ({XDG_RUNTIME_DIR='/runtime',HYPRLAND_INSTANCE_SIGNATURE='test'})[k]end}},{__index=_G})
 assert(loadfile(module_path,'t',env))().setup(api,opts.rules or {},'restart')
 local function advance(t)
  while true do
   table.sort(timers,function(a,b)if a.due==b.due then return a.id<b.id end return a.due<b.due end)
   local timer=timers[1];if not timer or timer.due>t then break end
   table.remove(timers,1);now=timer.due;timer.fn()
   if timer.spec.type=='repeat' then timer.due=now+timer.spec.timeout;timers[#timers+1]=timer end
  end
  now=t
 end
 return {advance=advance,event=function(n)events[n]()end,moves=moves,restarts=restarts,
 files=files,path=path,set_monitors=function(m)monitors=m end,
 writes=function()return writes end,rescues=function()return rescues end}
end
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local sig='eDP-1:0:0:1920:1080:1:0'
test('unrelated reload preserves manually assigned workspaces',function()
 local s=scenario({previous=sig..'\n4=HDMI-A-1\neDP-1\n',rules={{workspace='4',monitor='HDMI-A-1'}},workspaces={{id=4,name='4',monitor={name='eDP-1'}}}})
 s.advance(800);s.event('config.reloaded');s.advance(1600);assert(#s.moves==0)
end)
test('orphaned special workspace uses explicit special selector',function()
 local ws={id=-98,name='special:scratchpad',monitor={name='HDMI-A-1'}}
 local s=scenario({workspaces={ws}});s.advance(800);assert(#s.moves==1 and s.moves[1].workspace=='special:scratchpad' and s.moves[1].monitor=='eDP-1')
end)
test('entering extend applies configured assignments',function()
 local monitors={{name='eDP-1',x=0,y=0,width=1920,height=1080,scale=1,transform=0},{name='HDMI-A-1',x=1920,y=0,width=1920,height=1080,scale=1,transform=0}}
 local s=scenario({monitors=monitors,previous=sig..'\n\neDP-1\n',rules={{workspace='4',monitor='HDMI-A-1'}},workspaces={{id=4,name='4',monitor={name='eDP-1'}}}})
 s.advance(800);assert(#s.moves==1 and s.moves[1].monitor=='HDMI-A-1')
end)
test('resolution/scale change rebuilds bar once',function()
 local s=scenario({previous=sig..'\n\neDP-1\n',monitors={{name='eDP-1',x=0,y=0,width=1280,height=720,scale=1.5,transform=0}}})
 s.advance(800);assert(#s.restarts==1)
end)
test('rapid events debounce from last event',function()
 local s=scenario({previous='old\n\neDP-1\n'});s.advance(100);s.event('monitor.layout_changed');s.advance(300);s.event('monitor.layout_changed');s.advance(1099);assert(s.writes()==0);s.advance(1100);assert(s.writes()==1 and #s.restarts==1)
end)
test('uncommitted Monique transaction delays reconcile',function()
 local s=scenario({});s.files['/runtime/monique-applying']='123\n';s.files['/proc/123/stat']='alive';s.advance(1000);assert(s.writes()==0)
 s.files['/runtime/monique-applying']=nil;s.advance(1700);assert(s.writes()==1)
end)
test('persistent mid-session FALLBACK gets bounded recovery',function()
 local s=scenario({monitors={{name='FALLBACK'}}});s.advance(3999);assert(s.rescues()==0);s.advance(14000);assert(s.rescues()==3)
end)
print(passed..' behavior tests passed')
