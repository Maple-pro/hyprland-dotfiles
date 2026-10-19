#!/usr/bin/env bash
# Tests repository sources only; never starts services, windows or real mode switches.
set -euo pipefail
profile_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
while IFS= read -r -d '' file; do luac -p "$file"; done < <(find "$profile_dir/.config/hypr" -name '*.lua' -print0)
while IFS= read -r -d '' file; do bash -n "$file"; done < <(find "$profile_dir" -name '*.sh' -print0)
python3 - "$profile_dir" <<'PY'
import ast,json,re,sys
from pathlib import Path
root=Path(sys.argv[1])
for path in root.rglob('*.py'):ast.parse(path.read_text(),filename=str(path))
for path in (root/'.config/monique/profiles').glob('*.json'):json.loads(path.read_text())
waybar=json.loads(re.sub(r'//[^\n]*','',(root/'.config/waybar/config.jsonc').read_text()))
assert waybar['clock']['actions']['on-click-right']=='mode'
assert 'keyboard-state' not in waybar and 'custom/keyboard-state' in waybar
assert '-n2' in waybar['backlight']['on-scroll-down']
installer=(root/'install-hyprland.sh').read_text()
entries=re.search(r'ENTRIES=\(\n(.*?)\n\)',installer,re.S).group(1)
for line in entries.splitlines():
    item=line.strip()
    if not item or item.startswith('#'):continue
    assert (root/item).exists(),f'missing install entry: {item}'
for script in (root/'.config/hypr/scripts').glob('*'):
    if script.suffix in ('.sh','.py') or script.name=='keybinds.lua':
        assert script.stat().st_mode & 0o100,f'not executable: {script}'
print('PASS source syntax, JSONC behavior, executable modes and installer entries')
PY
lua "$profile_dir/tests/test-projection-startup.lua" "$profile_dir"
lua "$profile_dir/tests/test-projection-state.lua" "$profile_dir"
lua "$profile_dir/tests/test-dialog-workspace.lua" "$profile_dir"
python3 "$profile_dir/tests/test-battery.py"
if python3 -c 'from importlib.metadata import version; assert version("monique") == "0.8.3"' 2>/dev/null; then
    python3 "$profile_dir/tests/test-compat.py"
else
    printf '%s\n' 'SKIP Monique compatibility tests: system Monique 0.8.3 is required.'
fi
