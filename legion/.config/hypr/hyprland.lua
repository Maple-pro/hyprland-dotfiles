-- -----------------------------------------------------------------------------
-- Hyprland 0.55+ Lua configuration
-- Theme: soft Catppuccin Mocha-inspired palette
-- -----------------------------------------------------------------------------

local terminal    = "foot"
local fileManager = "krusader"
local menu        = "rofi -show drun"
local browser     = "google-chrome-stable"
local editor      = "kate"
local powerMenu   = "/home/yangfeng/.config/hypr/scripts/powermenu.sh"
local mainMod     = "SUPER"

-- -----------------------------------------------------------------------------
-- Environment
-- -----------------------------------------------------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_SCALE_FACTOR", "1.25")
hl.env("QT_SCALE_FACTOR_ROUNDING_POLICY", "RoundPreferFloor")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_IM_MODULE", "")

-- -----------------------------------------------------------------------------
-- Monitors
-- -----------------------------------------------------------------------------
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@60",
    position = "auto",
    scale    = 1.25,
})

-- -----------------------------------------------------------------------------
-- Autostart
-- -----------------------------------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("fcitx5 -d --replace")
    hl.exec_cmd("foot")
    hl.exec_cmd("mihomo-party")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- -----------------------------------------------------------------------------
-- Permissions used by common utilities
-- -----------------------------------------------------------------------------
hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprpicker", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/slurp", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")

-- -----------------------------------------------------------------------------
-- Input
-- -----------------------------------------------------------------------------
hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
            drag_lock      = true,
        },
    },
})

-- -----------------------------------------------------------------------------
-- Look and feel
-- -----------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = { top = 5, right = 12, bottom = 12, left = 12 },
        border_size = 2,

        col = {
            active_border = {
                colors = { "rgba(cba6f7ee)", "rgba(f5c2e7ee)" },
                angle  = 45,
            },
            inactive_border = "rgba(313244cc)",
        },

        resize_on_border    = true,
        hover_icon_on_border = true,
        allow_tearing       = false,
        layout              = "dwindle",
    },

    cursor = {
        inactive_timeout      = 4,
        no_hardware_cursors   = false,
    },

    decoration = {
        rounding       = 12,
        active_opacity   = 1.0,
        inactive_opacity = 0.94,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = 0xaa1a1b26,
        },

        blur = {
            enabled          = true,
            size             = 5,
            passes           = 2,
            ignore_opacity   = true,
            new_optimizations = true,
            xray             = false,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Curves and animation tree
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 }    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 }    } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 }       } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 }    } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 }     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- -----------------------------------------------------------------------------
-- Layouts
-- -----------------------------------------------------------------------------
hl.config({
    dwindle = {
        preserve_split     = true,
        force_split        = 0,
        smart_split        = false,
    },

    master = {
        new_status  = "master",
        new_on_top  = true,
        mfact       = 0.55,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- -----------------------------------------------------------------------------
-- Misc
-- -----------------------------------------------------------------------------
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
        vrr                     = 1,
    },
})

-- -----------------------------------------------------------------------------
-- Window rules
-- -----------------------------------------------------------------------------
hl.window_rule({
    name  = "float-file-manager",
    match = { class = "^(org.kde.dolphin|org.kde.krusader|krusader)$" },
    float = true,
    size  = { "(monitor_w*0.75)", "(monitor_h*0.75)" },
    center = true,
})

hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^pavucontrol$" },
    float = true,
})

hl.window_rule({
    name  = "float-blueman-manager",
    match = { class = "^blueman-manager$" },
    float = true,
})

hl.window_rule({
    name  = "float-network-manager",
    match = { class = "^(nm-connection-editor|nm-applet)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "float-picture-in-picture",
    match = { title = "^Picture-in-Picture$" },
    float = true,
    pin   = true,
})

hl.window_rule({
    name  = "flameshot-pin",
    match = { class = "^flameshot$" },
    float = true,
    pin   = true,
    no_anim = true,
    no_shadow = true,
    no_blur = true,
    border_size = 0,
    rounding = 0,
})

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- -----------------------------------------------------------------------------
-- Keybindings
-- -----------------------------------------------------------------------------

-- Launch applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + TAB",    hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + K",      hl.dsp.exec_cmd(editor))

-- Window control
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Utilities
hl.bind(mainMod .. " + S",      hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("PRINT",                hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind(mainMod .. " + C",      hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + X",      hl.dsp.exec_cmd(powerMenu))
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exit())

-- Focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move active window
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

-- Resize active window
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 40 0"))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -40"))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 40"))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + BRACKETLEFT",  hl.dsp.exec_cmd("hyprctl dispatch workspace m-1"))
hl.bind(mainMod .. " + BRACKETRIGHT", hl.dsp.exec_cmd("hyprctl dispatch workspace m+1"))
hl.bind(mainMod .. " + BACKSPACE",    hl.dsp.exec_cmd("hyprctl dispatch workspace previous"))

-- Scratchpad
hl.bind(mainMod .. " + GRAVE",        hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.window.move({ workspace = "special:scratchpad" }))

-- Mouse manipulation
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media and brightness keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("F4",                   hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                    { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                    { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                              { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                              { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                                { locked = true })
