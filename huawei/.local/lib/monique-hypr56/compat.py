"""User-local Monique compatibility for this Hyprland 0.56 Lua session.
No changes to the distribution package. CLI and daemon share one transaction lock.
"""
from contextlib import contextmanager
from pathlib import Path
import fcntl
import json
import os
import subprocess
import tempfile
import threading
import time
import inspect
import logging
import re
from importlib.metadata import version

_local = threading.local()

@contextmanager
def transaction():
    if getattr(_local, 'depth', 0):
        _local.depth += 1
        try:
            yield
        finally:
            _local.depth -= 1
        return
    path = Path(os.environ['XDG_RUNTIME_DIR']) / 'monique-projection.lock'
    with path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        marker = path.parent / 'monique-applying'
        marker.write_text(str(os.getpid()) + '\n')
        _local.depth = 1
        try:
            yield
        finally:
            _local.depth = 0
            marker.unlink(missing_ok=True)
            fcntl.flock(lock, fcntl.LOCK_UN)


def atomic_text(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def install():
    # Fail before patching anything when upstream private APIs change.
    if version('monique') != '0.8.3':
        raise RuntimeError('Monique compatibility requires 0.8.3; review ~/.local/lib/monique-hypr56/README.md after upgrading')
    from monique import utils, hypr_config, profile_manager, app, daemon
    from monique.hyprland import HyprlandIPC
    from monique.window import MainWindow
    for owner, names in ((MainWindow, ('_on_apply_clicked', '_on_confirm_response', '_do_revert')),
                         (daemon.MonitorDaemon, ('_pinned_profile', '_apply_best_profile'))):
        for name in names:
            if not callable(getattr(owner, name, None)):
                raise RuntimeError(f'Monique compatibility: missing {owner.__name__}.{name}')
    required = {'profile', 'use_description', 'hypr_config_format', 'update_sddm', 'update_greetd'}
    if not required.issubset(inspect.signature(HyprlandIPC.apply_profile).parameters):
        raise RuntimeError('Monique apply_profile signature changed; compatibility layer not installed')

    def atomic_json(path, data):
        atomic_text(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    utils.write_text = hypr_config.write_text = atomic_text
    utils.write_json = profile_manager.write_json = atomic_json

    from monique.models import MonitorConfig, ResolutionMode
    def get_monitors(self):
        data = self.command_json('monitors all')
        names = {str(m['id']): m['name'] for m in data}
        result = []
        for raw in data:
            monitor = MonitorConfig.from_hyprctl(raw)
            mirror = str(raw.get('mirrorOf', 'none'))
            monitor.mirror_of = names.get(mirror, '') if mirror != 'none' else ''
            result.append(monitor)
        return result
    HyprlandIPC.get_monitors = get_monitors

    original_load = profile_manager.ProfileManager.load
    def load(self, name):
        profile = original_load(self, name)
        # With port-name rules, a different projector on the same port must not
        # fail the daemon's description-based safety check.
        if profile and utils.load_app_settings().get('use_port_names'):
            try:
                current = {m.name: m for m in HyprlandIPC().get_monitors()}
                for monitor in profile.monitors:
                    if monitor.name in current:
                        monitor.description = current[monitor.name].description
                        # A saved projector mode may be unsupported on another device.
                        available = current[monitor.name].available_modes
                        if monitor.enabled and monitor.resolution_mode is ResolutionMode.EXPLICIT and available:
                            parsed = [re.fullmatch(r'(\d+)x(\d+)@([\d.]+)(?:Hz)?', item) for item in available]
                            supported = any(match and int(match[1]) == monitor.width
                                and int(match[2]) == monitor.height
                                and abs(float(match[3]) - monitor.refresh_rate) < .6 for match in parsed)
                            if not supported:
                                logging.getLogger('monique.compat').warning('%s: saved mode unavailable, using preferred', monitor.name)
                                monitor.resolution_mode = ResolutionMode.PREFERRED
            except OSError:
                pass
        return profile
    profile_manager.ProfileManager.load = load

    def move_workspace(self, workspace, monitor):
        script = ('hl.dispatch(hl.dsp.workspace.move({workspace=' + json.dumps(str(workspace))
                  + ',monitor=' + json.dumps(monitor) + '}))')
        result = self.command('eval ' + script)
        if 'error' in result.lower():
            raise RuntimeError(result)
        return result
    HyprlandIPC.move_workspace_to_monitor = move_workspace

    original_apply = HyprlandIPC.apply_profile
    def apply(self, profile, **options):
        with transaction():
            connected = {m.name for m in self.get_monitors() if m.name != 'FALLBACK'}
            enabled = {m.name for m in profile.monitors if m.enabled and not m.mirror_of}
            if not connected.intersection(enabled):
                raise RuntimeError('Profile has no connected standalone display; refusing to blank all outputs')
            # Syntax validation precedes any live write.
            source = profile.generate_lua_config(use_description=options.get('use_description', False),
                                                   supports_icc=self.supports_icc)
            check = subprocess.run(['luac', '-p', '-'], input=source, text=True, capture_output=True)
            if check.returncode:
                raise RuntimeError(check.stderr)
            paths = self.config_paths(hypr_config_format=options.get('hypr_config_format'))
            before = {p: p.read_text() if p.exists() else None for p in paths}
            options.update(update_sddm=False, update_greetd=False)
            try:
                # Hyprland 0.56 may retain a mirrored output without a wl_output
                # when unmirroring it. Recreate it while its source is STILL ON,
                # before applying a profile that may disable the source.
                current = {m.name: m for m in self.get_monitors()}
                for monitor in profile.monitors:
                    old = current.get(monitor.name)
                    if not (old and old.enabled and old.mirror_of and monitor.enabled and not monitor.mirror_of):
                        continue
                    sources = [m for m in current.values() if m.enabled and not m.mirror_of
                               and m.name != 'FALLBACK' and m.name != monitor.name]
                    if not sources:
                        raise RuntimeError('Cannot safely recreate mirrored output without an active source')
                    result = self.command('eval hl.monitor({output=' + json.dumps(monitor.name) + ',disabled=true})')
                    if 'error' in result.lower(): raise RuntimeError(result)
                    time.sleep(.2)
                    script = monitor.to_hyprland_lua_block(use_description=False, supports_icc=self.supports_icc)
                    script += '\nhl.monitor({output=' + json.dumps(monitor.name) + ',disabled=false,mirror="",position="auto-right"})'
                    result = self.command('eval ' + script)
                    if 'error' in result.lower(): raise RuntimeError(result)
                    time.sleep(.35)
                    # A successful capture proves the new Wayland output global
                    # exists. Do not disable the source if this step failed.
                    verified = subprocess.run(['grim', '-o', monitor.name, '-s', '.01', '-t', 'ppm', '/dev/null'],
                                              capture_output=True, text=True, timeout=5)
                    if verified.returncode:
                        raise RuntimeError('Recreated output is not exposed to Wayland: ' + verified.stderr)
                original_apply(self, profile, **options)
                errors = self.command('configerrors').strip()
                if errors:
                    raise RuntimeError('Hyprland config errors: ' + errors)
                # Retain the lock until the new output state has settled.
                deadline = time.monotonic() + 5
                stable = 0
                while time.monotonic() < deadline:
                    live = {m.name: m for m in self.get_monitors()}
                    matches = all(m.name not in connected or
                                  (m.name in live and live[m.name].enabled == m.enabled
                                   and (not m.enabled or live[m.name].mirror_of == m.mirror_of))
                                  for m in profile.monitors)
                    stable = stable + 1 if matches else 0
                    if stable >= 3:
                        break
                    time.sleep(.15)
                else:
                    raise RuntimeError('Timed out waiting for monitor profile to settle')
            except Exception:
                for path, old in before.items():
                    if old is None:
                        path.unlink(missing_ok=True)
                    else:
                        atomic_text(path, old)
                self.reload()
                raise
    HyprlandIPC.apply_profile = apply

    original_cli = app._apply
    def cli_apply(profile, ipc, mgr, *, pin):
        with transaction():
            original_cli(profile, ipc, mgr, pin=pin)
            mode = 'internal' if profile.name == 'pc-only' else profile.name
            if mode in ('internal', 'mirror', 'extend', 'external'):
                atomic_text(Path.home() / '.cache/hypr/project-mode', mode + '\n')
    app._apply = cli_apply

    original_pin = daemon.MonitorDaemon._pinned_profile
    def pinned(self, fingerprint):
        if utils.load_app_settings().get('use_port_names'):
            monitors = self._ipc.get_monitors() if self._ipc else []
            ports = {m.name for m in monitors if m.name != 'FALLBACK'}
            external = [m for m in monitors if not m.is_internal and m.name != 'FALLBACK']
            if monitors and not external:
                return self._profile_mgr.load('pc-only')
            pin = utils.get_pinned_profile()
            if pin and pin[0] in ('pc-only', 'mirror', 'extend', 'external'):
                profile = self._profile_mgr.load(pin[0])
                if profile and all(m.name in ports for m in profile.monitors if m.enabled):
                    return profile
        return original_pin(self, fingerprint)
    daemon.MonitorDaemon._pinned_profile = pinned

    # GUI Apply pins the new choice before returning; hold the same lock until
    # that state write completes as well, including its revert callbacks.
    from monique.window import MainWindow
    def locked_method(method):
        def call(self, *args, **kwargs):
            with transaction():
                return method(self, *args, **kwargs)
        return call
    for name in ('_on_apply_clicked', '_on_confirm_response', '_do_revert'):
        if hasattr(MainWindow, name):
            setattr(MainWindow, name, locked_method(getattr(MainWindow, name)))

    original_auto = daemon.MonitorDaemon._apply_best_profile
    async def auto_apply(self, ipc, *, force=False):
        with transaction():
            # A CLI operation may have selected another profile since our last event.
            fingerprint = {m.description for m in ipc.get_monitors() if m.description}
            active = utils.get_active_profile()
            if not force and active != self._last_applied_profile:
                chosen = self._pinned_profile(sorted(fingerprint))
                live = {m.name: m for m in ipc.get_monitors()}
                if chosen and chosen.name == active and all(
                    m.name not in live or (m.enabled == live[m.name].enabled and
                    (not m.enabled or m.mirror_of == live[m.name].mirror_of))
                    for m in chosen.monitors
                ):
                    self._last_applied_profile = active
                    self._last_applied_fingerprint = fingerprint
                    return  # CLI/GUI already committed this complete transaction.
            if active != self._last_applied_profile or fingerprint != self._last_applied_fingerprint:
                force = True
            await original_auto(self, ipc, force=force)
    daemon.MonitorDaemon._apply_best_profile = auto_apply
