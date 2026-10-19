#!/usr/bin/env python3
"""Stop graphical services when this compositor exits, including after a crash."""
import json
import os
from pathlib import Path
import subprocess
import time

signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
instances = json.loads(subprocess.check_output(['hyprctl', '-j', 'instances'], text=True))
pid = next((i['pid'] for i in instances if i['instance'] == signature), None)
if pid is None:
    raise SystemExit('Current Hyprland instance was not found')
stat = Path(f'/proc/{pid}/stat')
def identity():
    try:
        return stat.read_text().rsplit(')', 1)[1].split()[19]
    except (OSError, IndexError):
        return None
started = identity()
while started and identity() == started:
    time.sleep(2)
subprocess.run(['systemctl', '--user', 'stop', '--no-block', 'graphical-session.target'], check=True)
