# Prefer user shims. SDDM starts the Wayland session through a zsh login shell,
# so ~/.local/bin must be on PATH before start-hyprland resolves "Hyprland".
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
