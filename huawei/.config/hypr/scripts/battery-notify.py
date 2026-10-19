#!/usr/bin/env python3
"""Notify once per discharge threshold; never suspend a working desktop."""
import json
import os
from pathlib import Path
import subprocess

def check(battery, old):
    try:
        percent=int((battery/'capacity').read_text())
        status=(battery/'status').read_text().strip()
    except (OSError, ValueError):
        return None
    if status != 'Discharging' or percent > 25:
        return 0
    level=3 if percent <= 5 else 2 if percent <= 10 else 1 if percent <= 20 else 0
    if level > old:
        subprocess.run(['notify-send','-a','Battery','-i','battery-caution',
            '-u','critical' if level >= 2 else 'normal','-h',f'string:x-dunst-stack-tag:battery-{battery.name}',
            '电量不足',f'剩余 {percent}%，请接通电源。'],check=True,timeout=10)
    return max(old,level)

def main():
    state=Path(os.environ['XDG_RUNTIME_DIR'])/'hyprland-battery-state.json'
    try:
        old=json.loads(state.read_text())
    except (OSError,ValueError):
        old={}
    new={}
    for battery in Path('/sys/class/power_supply').glob('*'):
        try:
            if (battery/'type').read_text().strip() != 'Battery': continue
        except OSError: continue
        level=check(battery,old.get(battery.name,0))
        if level is not None: new[battery.name]=level
    temp=state.with_suffix('.tmp');temp.write_text(json.dumps(new));temp.replace(state)
if __name__=='__main__':main()
