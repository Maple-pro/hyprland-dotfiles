local profile=assert(arg[1], 'pass the Legion profile directory')
local module_path=profile .. '/.config/hypr/scripts/projection-state.lua'
local BASE='/runtime/hypr-projection-test'
local passed=0

-- The compositor must never hold a Lua timer: Hyprland 0.57 segfaults in
-- CConfigManager::cleanTimers() when one is still registered at teardown. The
-- staging delay lives in projection-debounce.sh, so the module is driven here by
-- calling trigger('sample')/trigger('settle') the way that helper does.
local function scenario(opts)
 local files={}
 local events,moves,restarts,spawned={},{},{},{}
 local rescues=0
 local monitors=opts.monitors or {{name='eDP-1',x=0,y=0,width=1920,height=1080,scale=1,transform=0}}
 if opts.previous then files[BASE]=opts.previous end
 local io_api={open=function(name,mode)
  if mode=='r' then
   local data=files[name]
   if name:match('/sys/class/drm/card0%-eDP%-1/status') then data='connected' end
   if not data then return nil end
   return {read=function(_,kind)if kind=='*l' then return data:match('[^\n]*') else return data end end,close=function()end}
  end
  files[name]=''
  return {write=function(_,...)local args={...};for _,s in ipairs(args)do files[name]=files[name]..s end end,close=function()end}
 end}
 local api={get_monitors=function()return monitors end,get_workspaces=function()return opts.workspaces or {} end,
  on=function(n,f)events[n]=f end,
  exec_cmd=function(cmd)spawned[#spawned+1]=cmd end,
  monitor=function(spec)
   assert(spec.mode=="2560x1600@60" and spec.scale==1.25,"Legion panel settings changed")
   rescues=rescues+1
  end,
  timer=function()error('projection-state must not register hl.timer')end,
  dsp={workspace={move=function(spec)return spec end}},dispatch=function(d)moves[#moves+1]=d end}
 local env=setmetatable({dofile=function(path)
  return dofile((path:gsub('^/home/yangfeng/',profile .. '/')))
 end,io=io_api,os={getenv=function(k)return ({XDG_RUNTIME_DIR='/runtime',HYPRLAND_INSTANCE_SIGNATURE='test'})[k]end}},{__index=_G})
 local module=assert(loadfile(module_path,'t',env))()
 module.setup(api,opts.rules or {},'/bar/restart')
 -- trigger() resolves the compositor API through _G, exactly like `hyprctl repl`.
 _G.hl=api
 return {files=files,event=function(n)assert(events[n],'no handler for '..n)()end,
  trigger=function(kind)return module.trigger(kind)end,
  moves=moves,spawned=spawned,rescues=function()return rescues end,
  restarts=function()local n=0;for _,c in ipairs(spawned)do if c:find('/bar/restart',1,true)then n=n+1 end end;return n end,
  set_monitors=function(m)monitors=m end}
end

local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local sig='eDP-1:0:0:1920:1080:1:0'
local two={{name='eDP-1',x=0,y=0,width=1920,height=1080,scale=1,transform=0},
 {name='HDMI-A-1',x=1920,y=0,width=1920,height=1080,scale=1,transform=0}}

test('setup persists the rules for the IPC side and starts one debounce pass',function()
 local s=scenario({rules={{workspace='4',monitor='HDMI-A-1'}}})
 assert(s.files[BASE..'.ctx']=='/bar/restart\n4=HDMI-A-1\n')
 assert(#s.spawned==1 and s.spawned[1]:match('projection%-debounce%.sh'),'helper not spawned')
end)

test('every monitor and config event spawns the debounce helper',function()
 local s=scenario({})
 for _,name in ipairs({'config.reloaded','monitor.added','monitor.removed','monitor.layout_changed'}) do s.event(name) end
 assert(#s.spawned==5,'expected 1 setup pass + 4 event passes, got '..#s.spawned)
end)

test('never registers an hl.timer',function()
 local s=scenario({})
 assert(s.trigger('sample')=='sampled')
 assert(s.trigger('settle')=='reconciled')
end)

test('settle without a matching sample is ignored',function()
 local s=scenario({})
 assert(s.trigger('settle')=='unstable')
 assert(s.files[BASE]==nil)
end)

test('trigger without a context is a no-op',function()
 local s=scenario({})
 s.files[BASE..'.ctx']=nil
 assert(s.trigger('settle')=='no-context')
end)

test('unrelated reload preserves manually assigned workspaces',function()
 local s=scenario({previous=sig..'\n4=HDMI-A-1\neDP-1\n',rules={{workspace='4',monitor='HDMI-A-1'}},workspaces={{id=4,name='4',monitor={name='eDP-1'}}}})
 s.trigger('sample');s.trigger('settle')
 assert(#s.moves==0)
end)

test('orphaned special workspace uses explicit special selector',function()
 local ws={id=-98,name='special:scratchpad',monitor={name='HDMI-A-1'}}
 local s=scenario({workspaces={ws}})
 s.trigger('sample');s.trigger('settle')
 assert(#s.moves==1 and s.moves[1].workspace=='special:scratchpad' and s.moves[1].monitor=='eDP-1')
end)

test('entering extend applies configured assignments',function()
 local s=scenario({monitors=two,previous=sig..'\n\neDP-1\n',rules={{workspace='4',monitor='HDMI-A-1'}},workspaces={{id=4,name='4',monitor={name='eDP-1'}}}})
 s.trigger('sample');s.trigger('settle')
 assert(#s.moves==1 and s.moves[1].monitor=='HDMI-A-1')
end)

test('resolution/scale change rebuilds bar once',function()
 local s=scenario({previous=sig..'\n\neDP-1\n',monitors={{name='eDP-1',x=0,y=0,width=1280,height=720,scale=1.5,transform=0}}})
 s.trigger('sample');s.trigger('settle')
 assert(s.restarts()==1,'bar not restarted after a signature change')
end)

test('layout that moved between sample and settle is not reconciled',function()
 local s=scenario({monitors=two,rules={{workspace='4',monitor='HDMI-A-1'}},workspaces={{id=4,name='4',monitor={name='eDP-1'}}}})
 assert(s.trigger('sample')=='sampled')
 s.set_monitors({{name='eDP-1',x=0,y=0,width=1280,height=720,scale=1,transform=0}})
 assert(s.trigger('settle')=='unstable')
 assert(#s.moves==0)
end)

test('uncommitted Monique transaction delays reconcile',function()
 local s=scenario({})
 s.files['/runtime/monique-applying']='123\n'
 s.files['/proc/123/stat']='alive'
 assert(s.trigger('settle')=='busy')
 assert(s.files[BASE]==nil)
 s.files['/runtime/monique-applying']=nil
 s.trigger('sample');assert(s.trigger('settle')=='reconciled')
end)

test('persistent mid-session FALLBACK gets bounded recovery',function()
 local s=scenario({monitors={{name='FALLBACK'}}})
 for _=1,5 do s.trigger('sample');s.trigger('settle') end
 assert(s.rescues()==3,'expected 3 rescue attempts, got '..s.rescues())
end)

print(passed..' behavior tests passed')
