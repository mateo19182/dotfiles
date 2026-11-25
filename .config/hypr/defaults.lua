-- Base settings carried over from Omarchy's defaults. Personal tweaks go in the
-- other files (looknfeel.lua, input.lua...), which load after this one.

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Neutral until Noctalia writes palette colors (hypr/noctalia.lua) on first start.
local active_border = "rgb(b0b0b0)"
local inactive_border = "rgb(1c1c1c)"

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = active_border,
      inactive_border = inactive_border,
    },
    resize_on_border = true,
    extend_border_grab_area = 8,
    hover_icon_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 0,
    shadow = { enabled = false },
    blur = { enabled = false },
  },

  group = {
    col = {
      border_active = active_border,
      border_inactive = inactive_border,
    },
    groupbar = {
      font_size = 12,
      font_family = "monospace",
      indicator_height = 1,
      height = 22,
      gradients = true,
      text_color = "rgb(ffffff)",
      text_color_inactive = "rgba(ffffff90)",
      col = {
        active = "rgba(00000040)",
        inactive = "rgba(00000020)",
      },
    },
  },

  dwindle = {
    preserve_split = true,
    force_split = 2,
  },

  scrolling = {
    column_width = 0.49,
  },

  master = {
    new_status = "master",
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = "rgb(000000)",
    disable_scale_notification = true,
    focus_on_activate = true,
    anr_missed_pings = 3,
    on_focus_under_fullscreen = 1,
    initial_workspace_tracking = 0,
    allow_session_lock_restore = true,
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
  },

  cursor = {
    hide_on_key_press = true,
    warp_on_change_workspace = 1,
  },

  binds = {
    hide_special_on_workspace_change = true,
  },

  input = {
    follow_mouse = 1,
    sensitivity = 0,
    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,
    touchpad = {
      natural_scroll = false,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
    },
  },

  xwayland = {
    force_zero_scaling = true,
  },

  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },
})

-- Floating dialogs and small utilities.
o.window({ tag = "floating-window" }, { float = true, center = true, size = { 875, 600 } })
o.window("(org.gnome.NautilusPreviewer|imv|mpv|org.pulseaudio.pavucontrol|nm-connection-editor)", {
  tag = "+floating-window",
})
o.window("xdg-desktop-portal-gtk", { tag = "+floating-window" })
o.window({
  class = "(org.gnome.Nautilus|code|Code|cursor|Cursor)",
  title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)",
}, { tag = "+floating-window" })

-- Terminals get a tag so the clipboard bindings can tell them apart.
o.window("(Alacritty|kitty|com.mitchellh.ghostty)", { tag = "+terminal" })

-- Picture-in-picture.
o.window({ title = "(Picture.?in.?[Pp]icture)" }, { float = true, pin = true, size = { 600, 338 } })

-- Noctalia settings window and its layers (from Noctalia's Hyprland guide).
o.window("dev.noctalia.Noctalia", { float = true, size = "monitor_w*0.5625 monitor_h*0.85" })
hl.layer_rule({
  name = "noctalia-no-anim",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
  },
  no_anim = true,
})

-- Don't let the screen sleep while something is fullscreen.
o.window(".*", { idle_inhibit = "fullscreen" })
