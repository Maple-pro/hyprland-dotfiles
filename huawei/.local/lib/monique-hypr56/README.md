# Local Monique compatibility

Tested with Monique 0.8.3 and Hyprland 0.56.2. System packages remain unmodified.
Both ~/.local/bin/monique and moniqued import compat.install(). The GUI desktop
entry and systemd daemon use these wrappers. A version/API guard fails before
patching if Monique changes; review this module instead of suppressing the guard.

Responsibilities: resolve mirror IDs to names; serialize GUI/CLI/daemon changes;
atomic monitor config/state writes; fail-safe restore; recreate a mirrored output
before disabling its source; validate the actual mirror source; adapt an
unsupported saved display mode to preferred for a newly connected projector.

The runtime monique-applying marker contains the lock holder PID. Hyprland's
projection-state waits for this transaction to finish before moving workspaces or
rebuilding Waybar. Stale markers from dead processes are ignored.

After upgrades: run huawei/tests/run.sh from the dotfiles repository,
then test all profile transitions, physical hotplug and sleep/resume when the
current desktop has no unsaved work. Never remove the safety checks just to get a
successful exit status. CLI switch failures are logged in
~/.local/state/hyprland/projection.log; daemon failures use journalctl --user -u
moniqued.service. Upstream private methods must be re-reviewed on upgrade.

Workspace behavior: projection-state applies profile assignments only when a
profile/topology changes. An unrelated config reload preserves manual moves.
Dialogs: the Lua API does not expose an exact transient-parent object. A dialog
fallback therefore requires a modal/native floating window and exactly one
same-class, same-process top-level candidate. Ambiguous multi-document parents
retain native placement; ordinary new top-level windows are never gathered by
class alone. Special/named workspaces use explicit selectors; passing Workspace
objects through the 0.56 dispatcher did not correctly move our live probe.
