-- MyRice configuration for Hyprland's Lua config API.

local mainMod = "SUPER"

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = "rgba(ffffffff)",
            inactive_border = "rgba(7f7f7faa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            xray = false,
        },
        shadow = {
            enabled = true,
            range = 16,
            render_power = 3,
            color = "rgba(00000055)",
        },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
    xwayland = { force_zero_scaling = true },
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle,caps:escape",
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity = 0,
        scroll_factor = 0.5,
        touchpad = {
            natural_scroll = true,
            clickfinger_behavior = true,
            tap_to_click = true,
            disable_while_typing = true,
            scroll_factor = 0.5,
        },
    },
    gestures = { workspace_swipe_touch = false },
})

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("GTK_THEME", "adw-gtk3-dark")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("LANG", "ru_RU.UTF-8")
hl.env("LC_MESSAGES", "ru_RU.UTF-8")
hl.env("LC_TIME", "ru_RU.UTF-8")
hl.env("LC_MONETARY", "ru_RU.UTF-8")
hl.env("LC_MEASUREMENT", "ru_RU.UTF-8")
hl.env("LC_PAPER", "ru_RU.UTF-8")
hl.env("PATH", (os.getenv("HOME") or "") .. "/.local/bin:" .. (os.getenv("HOME") or "") .. "/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/lib/jvm/default/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- Prefer the native Wayland backend for every Electron application started
-- from this Hyprland session. This avoids XWayland popup/blur artifacts.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0000000000 })

-- Hardware-specific monitor layouts live outside the repository.
local local_config_dir = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local local_device_file = local_config_dir .. "/myrice-local/hypr/device.lua"
local local_device_handle = io.open(local_device_file, "r")
if local_device_handle then
    local_device_handle:close()
    local ok, err = pcall(dofile, local_device_file)
    if not ok then
        print("MyRice local device config was not applied: " .. err)
    end
end

hl.curve("easeOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "easeOut" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "center-floating", match = { float = true }, center = true })
hl.window_rule({ name = "rofi", match = { class = "^(Rofi)$" }, float = true, center = true })
hl.window_rule({ name = "clipse", match = { class = "^(clipse)$" }, float = true, center = true, size = "820 560", rounding = 14, pin = true })
hl.window_rule({ name = "scale", match = { class = "^(hypr-scale)$" }, float = true, center = true, size = "380 120", rounding = 12, pin = true })
hl.window_rule({ name = "quickshell", match = { class = "^(org\\.quickshell)$" }, border_size = 0 })
hl.window_rule({ name = "settings", match = { class = "^(org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager|AmneziaVPN)$" }, float = true, center = true })
hl.window_rule({ name = "settings-size", match = { class = "^(org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager)$" }, size = "900 620" })

for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("qs")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-apply.sh restore")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sh -c 'plugin=\"$HOME/.local/src/hypr-autoscroll/build/hypr-autoscroll.so\"; [ ! -f \"$plugin\" ] || hyprctl plugin load \"$plugin\"'")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
end)

local function command(key, value, options)
    hl.bind(key, hl.dsp.exec_cmd(value), options)
end

command(mainMod .. " + T", "ghostty")
hl.bind(mainMod .. " + TAB", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
command(mainMod .. " + E", "nautilus --new-window")
command(mainMod .. " + SPACE", "qs ipc call launcher toggle")
hl.bind(mainMod .. " + G", hl.dsp.window.float())
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
command(mainMod .. " + V", "~/.config/hypr/scripts/clipboard.sh")
command(mainMod .. " + W", "qs ipc call wallpaper toggle")
command(mainMod .. " + N", "qs ipc call notifications toggle")
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
command(mainMod .. " + SHIFT + S", "~/.config/hypr/scripts/move-to-special-silent.sh")
command(mainMod .. " + ALT + S", "~/.local/bin/sudo-nopasswd-toggle")
hl.bind(mainMod .. " + B", hl.dsp.layout("togglesplit"))
command(mainMod .. " + P", "qs ipc call display open")
command(mainMod .. " + F1", "qs ipc call keybinds open")
command(mainMod .. " + slash", "qs ipc call keybinds open")
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.float())
command(mainMod .. " + SHIFT + M", "~/.local/bin/server-mode-toggle")
command(mainMod .. " + SHIFT + R", "~/.config/hypr/scripts/toggle-ru-ctrl-latin.sh")

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

command(mainMod .. " + F12", "~/.config/hypr/scripts/frozen-screenshot.sh open")
command(mainMod .. " + SHIFT + F12", "~/.config/hypr/scripts/screenshot.sh output")
command("PRINT", "~/.config/hypr/scripts/screenshot.sh area")
command("SHIFT + PRINT", "~/.config/hypr/scripts/screenshot.sh output")
command(mainMod .. " + SHIFT + W", "nm-connection-editor")
command(mainMod .. " + ESCAPE", "qs ipc call power open")
command(mainMod .. " + SHIFT + ESCAPE", "ghostty -e btop")
command(mainMod .. " + L", "~/.local/bin/myrice-action lock")
command(mainMod .. " + SHIFT + P", "~/.local/bin/myrice-scene --dry-run presentation")
command(mainMod .. " + CTRL + P", "~/.local/bin/myrice-scene presentation")
command(mainMod .. " + A", "ghostty -e ollama run qwen2.5:7b")
command(mainMod .. " + CTRL + equal", "~/.config/hypr/scripts/scale.sh up")
command(mainMod .. " + CTRL + minus", "~/.config/hypr/scripts/scale.sh down")
command(mainMod .. " + CTRL + 0", "~/.config/hypr/scripts/scale.sh reset")
command(mainMod .. " + CTRL + S", "qs ipc call scale open")
command("XF86AudioRaiseVolume", "~/.local/bin/myrice-action audio up", { locked = true, repeating = true })
command("XF86AudioLowerVolume", "~/.local/bin/myrice-action audio down", { locked = true, repeating = true })
command("XF86AudioMute", "~/.local/bin/myrice-action audio mute", { locked = true, repeating = true })
command("XF86MonBrightnessUp", "~/.local/bin/myrice-action brightness up", { locked = true, repeating = true })
command("XF86MonBrightnessDown", "~/.local/bin/myrice-action brightness down", { locked = true, repeating = true })
