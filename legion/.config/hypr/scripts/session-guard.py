#!/usr/bin/env python3
"""Stop graphical services when this compositor exits, including after a crash.

Liveness is taken from the compositor's Wayland socket, not from
`hyprctl -j instances`: that command answers with an empty or truncated payload
while a session is starting up or dying (it did on 2026-11-03 15:58:16), and the
resulting JSONDecodeError used to kill the guard before it could clean anything
up.
"""
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

TARGET = "graphical-session.target"
POLL = 2.0
STARTUP_TIMEOUT = 10.0
SYSTEMCTL_TIMEOUT = 5.0
DRY_RUN = os.environ.get("SESSION_GUARD_DRY_RUN") == "1"


def log(message):
    print(f"session-guard: {message}", file=sys.stderr, flush=True)


def instance_paths():
    """(<runtime>/hypr/<signature>, <socket>) or (None, None) when unset."""
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not runtime or not signature:
        return None, None
    base = Path(runtime) / "hypr" / signature
    return base, base / ".socket.sock"


def serving(path):
    """True while the compositor accepts connections on its Wayland socket."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(1.0)
            client.connect(str(path))
        return True
    except (ConnectionRefusedError, FileNotFoundError):
        return False
    except OSError:
        # Backlog full or interrupted: not evidence that the compositor is gone.
        return True


def wait_until_serving(path, timeout=STARTUP_TIMEOUT):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if serving(path):
            return True
        time.sleep(0.25)
    return False


def stop_session_services():
    command = ["systemctl", "--user", "stop", "--no-block", TARGET]
    if DRY_RUN:
        log(f"dry run: would run {' '.join(command)}")
        return
    try:
        subprocess.run(command, check=False, timeout=SYSTEMCTL_TIMEOUT)
    except (OSError, subprocess.SubprocessError) as error:
        log(f"could not stop {TARGET}: {error}")


def main():
    base, wayland_socket = instance_paths()
    if base is None:
        log("XDG_RUNTIME_DIR or HYPRLAND_INSTANCE_SIGNATURE is unset, nothing to guard")
        return 0

    if not wait_until_serving(wayland_socket):
        if base.exists():
            # The instance directory exists but nothing serves it: it died.
            log(f"{wayland_socket} is not accepting connections, compositor is gone")
            stop_session_services()
            return 0
        log(f"instance {base.name} was never created, nothing to guard")
        # Exit 0: the unit uses Restart=on-failure, a failing guard would just loop.
        return 0

    log(f"guarding instance {base.name}")
    while serving(wayland_socket):
        time.sleep(POLL)
    log("compositor stopped, cleaning up the session")
    stop_session_services()
    return 0


if __name__ == "__main__":
    sys.exit(main())
