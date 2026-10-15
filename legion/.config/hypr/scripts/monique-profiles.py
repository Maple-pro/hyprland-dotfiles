#!/usr/bin/env python3
"""Build Legion projection profiles from connected hardware; keep edits on --ensure.

With no external display, create a preferred-mode HDMI placeholder. The switch
wrapper refuses external modes until a real external display is connected.
"""
import copy
from pathlib import Path

from monique.detect import detect_backend
from monique.models import MonitorConfig, PositionMode, Profile, ResolutionMode, WorkspaceRule


def build_profiles(monitors):
    internal = next((m for m in monitors if m.name.startswith(('eDP-', 'LVDS-'))), None)
    if internal is None:
        raise RuntimeError('No laptop panel detected; refusing to rewrite profiles')
    external = next((m for m in monitors if m.name != internal.name), None)
    if external is None:
        external = MonitorConfig(name='HDMI-A-1', resolution_mode=ResolutionMode.PREFERRED)
    profiles = []
    for name in ('pc-only', 'mirror', 'extend', 'external'):
        i, e = copy.deepcopy(internal), copy.deepcopy(external)
        i.width, i.height, i.refresh_rate, i.scale = 2560, 1600, 60.0, 1.25
        i.resolution_mode = ResolutionMode.EXPLICIT
        i.x, i.y, i.position_mode = 0, 0, PositionMode.EXPLICIT
        i.enabled, i.mirror_of, i.focus_at_startup = name != 'external', '', name != 'external'
        e.enabled, e.focus_at_startup = name != 'pc-only', name == 'external'
        e.resolution_mode, e.scale = ResolutionMode.PREFERRED, 1.0
        e.mirror_of = i.name if name == 'mirror' else ''
        e.position_mode = PositionMode.AUTO_LEFT if name == 'extend' else PositionMode.AUTO
        if name == 'external':
            e.x, e.y, e.position_mode = 0, 0, PositionMode.EXPLICIT
        p = Profile(name=name, monitors=[i, e])
        if name == 'extend':
            p.workspace_rules = [WorkspaceRule(workspace='1', monitor=i.name, default=True)]
            p.workspace_rules += [WorkspaceRule(workspace=str(n), monitor=e.name, default=n == 2)
                                  for n in range(2, 11)]
        profiles.append(p)
    return profiles


def main():
    import argparse
    import json
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ensure', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    monitors = detect_backend().get_monitors()
    profiles = build_profiles(monitors)
    directory = args.output or Path.home() / '.config/monique/profiles'
    existing = directory / 'extend.json'
    if args.ensure and existing.exists():
        saved = json.loads(existing.read_text())
        live = {(m.name, m.description) for m in monitors}
        stored = {(m['name'], m.get('description', '')) for m in saved['monitors']}
        # Disconnection should preserve the user's saved external hardware.
        if live <= stored and all((directory / f'{p.name}.json').exists() for p in profiles):
            return
    directory.mkdir(parents=True, exist_ok=True)
    for profile in profiles:
        (directory / f'{profile.name}.json').write_text(json.dumps(profile.to_dict(), indent=2) + '\n')


if __name__ == '__main__':
    main()
