#!/usr/bin/env python3
"""Read only LED state, never raw keyboard events."""
import json
from pathlib import Path
values=[]
for path in Path('/sys/class/leds').glob('*::capslock/brightness'):
    try:
        values.append(int(path.read_text().strip()))
    except (OSError, ValueError):
        pass
locked=any(values)
print(json.dumps({'text': '󰪛' if locked else '󰪟', 'class': 'locked' if locked else 'unlocked',
                  'tooltip': 'Caps Lock: ' + ('on' if locked else 'off') if values else 'Caps Lock state unavailable'}, ensure_ascii=False))
