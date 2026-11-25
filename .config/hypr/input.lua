-- https://wiki.hypr.land/Configuring/Variables/#input
hl.config({
  input = {
    kb_layout = "es-ansi",
    kb_options = "",
    repeat_delay = 600,
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = false,
    },
  },
})

-- Per-app touchpad scroll speed.
o.window("(Alacritty|kitty)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
