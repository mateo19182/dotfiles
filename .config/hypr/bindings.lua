-- Keybindings: Omarchy's layout, with Noctalia behind the menus and panels.
local n = o.noctalia

---------------------------------------------------------------------------
-- Apps
---------------------------------------------------------------------------
o.bind("SUPER + RETURN", "Terminal", o.launch("ghostty"))
o.bind("SUPER + BACKSPACE", "Terminal", o.launch("ghostty"))
o.bind("SUPER + ALT + RETURN", "Tmux", o.launch("ghostty -e tmux new-session -A -s main"))
o.bind("SUPER + SHIFT + RETURN", "Browser", o.launch("google-chrome-stable"))
o.bind("SUPER + SHIFT + B", "Browser", o.launch("google-chrome-stable"))
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", o.launch("google-chrome-stable --incognito"))
o.bind("SUPER + SHIFT + F", "File manager", o.launch("nautilus --new-window"))
o.bind("SUPER + SHIFT + N", "Editor", o.launch("code"))
o.bind("SUPER + SHIFT + T", "Activity", o.launch("ghostty -e btop"))
o.bind("SUPER + SHIFT + M", "Music", o.launch_or_focus("spotify", o.launch("spotify")))
o.bind("SUPER + SHIFT + G", "Signal", o.launch_or_focus("signal", o.launch("signal-desktop")))
o.bind("SUPER + SHIFT + O", "Obsidian", o.launch_or_focus("obsidian", o.launch("obsidian")))
o.bind("SUPER + SHIFT + L", "Linkwarden add", o.launch("ghostty -e linkwarden-add"))

-- Web apps
o.bind("SUPER + SHIFT + A", "ChatGPT", o.webapp("https://chatgpt.com"))
o.bind("SUPER + SHIFT + Y", "YouTube", o.webapp("https://youtube.com/"))
o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", o.launch_or_focus("web.whatsapp.com", o.webapp("https://web.whatsapp.com/")))
o.bind("SUPER + SHIFT + CTRL + G", "Google Messages", o.launch_or_focus("messages.google.com", o.webapp("https://messages.google.com/web/conversations")))
o.bind("SUPER + SHIFT + P", "Google Photos", o.launch_or_focus("photos.google.com", o.webapp("https://photos.google.com/")))
o.bind("SUPER + SHIFT + S", "Google Maps", o.launch_or_focus("maps.google.com", o.webapp("https://maps.google.com/")))
o.bind("SUPER + SHIFT + X", "X", o.webapp("https://x.com/"))

---------------------------------------------------------------------------
-- Noctalia: launcher, menus, panels
---------------------------------------------------------------------------
o.bind("SUPER + SPACE", "Launcher", n("panel-toggle launcher"))
o.bind("SUPER + ALT + SPACE", "Control center", n("panel-toggle control-center"))
o.bind("SUPER + ESCAPE", "Session menu", n("panel-toggle session"))
o.bind("XF86PowerOff", "Session menu", n("panel-toggle session"), { locked = true })
o.bind("SUPER + CTRL + V", "Clipboard history", n("panel-toggle clipboard"))
o.bind("SUPER + CTRL + E", "Emojis", n("panel-toggle launcher /emo"))
-- The launcher evaluates math directly.
o.bind("SUPER + SHIFT + C", "Calculator", n("panel-toggle launcher"))
o.bind("XF86Calculator", "Calculator", n("panel-toggle launcher"))
o.bind("SUPER + CTRL + W", "Wallpaper", n("panel-toggle wallpaper"))
o.bind("SUPER + CTRL + SPACE", "Wallpaper", n("panel-toggle wallpaper"))
o.bind("SUPER + CTRL + T", "Settings", n("settings-toggle"))
o.bind("SUPER + SHIFT + SPACE", "Toggle bar", n("bar-toggle"))
o.bind("SUPER + CTRL + L", "Lock", n("session lock"))
o.bind("SUPER + CTRL + I", "Toggle idle (caffeine)", n("caffeine-toggle"))
o.bind("SUPER + CTRL + N", "Toggle night light", n("nightlight-force-toggle"))
o.bind("ALT + TAB", "Window switcher", n("window-switcher hold"))
o.bind("ALT + SHIFT + TAB", "Window switcher (reverse)", n("window-switcher hold reverse"))

---------------------------------------------------------------------------
-- Capture
---------------------------------------------------------------------------
local lastScreenshot = o.sh(os.getenv("XDG_RUNTIME_DIR") .. "/noctalia-last-screenshot.png")
local editScreenshot = n("annotate --no-pipe-to-command --no-copy-on-close " .. lastScreenshot)
local captureAndEdit = [[tmp=$(mktemp ]] .. lastScreenshot .. [[.XXXXXX) || exit 1
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" && mv -f -- "$tmp" ]] .. lastScreenshot .. " && " .. editScreenshot
local captureRegion = n("screenshot-region --no-confirm-region --no-annotate --copy-to-clipboard"
  .. " --no-save-to-file --pipe-to-command --pipe-command " .. o.sh(captureAndEdit))
o.bind("PRINT", "Copy and edit screenshot region", captureRegion)
o.bind("SUPER + SHIFT + Q", "Copy and edit screenshot region", captureRegion)
o.bind("CTRL + SHIFT + PRINT", "Edit last screenshot", editScreenshot)
o.bind("SHIFT + PRINT", "Screenshot (full screen)", n("screenshot-fullscreen"))
o.bind("CTRL + PRINT", "Screenshot (window)", n("screenshot-window"))
o.bind("ALT + PRINT", "Screen recording", "screenrecord")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")

---------------------------------------------------------------------------
-- Dictation (Hex)
---------------------------------------------------------------------------
o.bind("F9", "Dictation (hold to talk)", hl.dsp.global("anomaly.hex:dictation"))
o.bind("SUPER + CTRL + X", "Toggle dictation", "hex dictation toggle")

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
o.bind("SUPER + W", "Close window", hl.dsp.window.close())
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
o.bind("SUPER + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + P", "Pseudo window", hl.dsp.window.pseudo())
o.bind("SUPER + T", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
o.bind("SUPER + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + ALT + F", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))

o.bind("SUPER + LEFT", "Focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + RIGHT", "Focus right", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + UP", "Focus up", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + DOWN", "Focus down", hl.dsp.focus({ direction = "d" }))

o.bind("SUPER + SHIFT + LEFT", "Swap left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + RIGHT", "Swap right", hl.dsp.window.swap({ direction = "r" }))
o.bind("SUPER + SHIFT + UP", "Swap up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + DOWN", "Swap down", hl.dsp.window.swap({ direction = "d" }))

-- code:20 / code:21 are the keys right of 0 on any layout.
o.bind("SUPER + code:20", "Grow left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
o.bind("SUPER + code:21", "Shrink left", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
o.bind("SUPER + SHIFT + code:20", "Shrink up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
o.bind("SUPER + SHIFT + code:21", "Grow down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

o.bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Groups
o.bind("SUPER + G", "Toggle group", hl.dsp.group.toggle())
o.bind("SUPER + ALT + G", "Leave group", hl.dsp.window.move({ out_of_group = true }))
o.bind("SUPER + ALT + LEFT", "Into group left", hl.dsp.window.move({ into_group = "l" }))
o.bind("SUPER + ALT + RIGHT", "Into group right", hl.dsp.window.move({ into_group = "r" }))
o.bind("SUPER + ALT + UP", "Into group up", hl.dsp.window.move({ into_group = "u" }))
o.bind("SUPER + ALT + DOWN", "Into group down", hl.dsp.window.move({ into_group = "d" }))
o.bind("SUPER + ALT + TAB", "Next in group", hl.dsp.group.next())
o.bind("SUPER + ALT + SHIFT + TAB", "Previous in group", hl.dsp.group.prev())
o.bind("SUPER + CTRL + LEFT", "Previous in group", hl.dsp.group.prev())
o.bind("SUPER + CTRL + RIGHT", "Next in group", hl.dsp.group.next())

---------------------------------------------------------------------------
-- Workspaces (code:10..19 are the number row on any layout)
---------------------------------------------------------------------------
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  local id = tostring(workspace)
  o.bind("SUPER + " .. key, "Workspace " .. id, hl.dsp.focus({ workspace = id }))
  o.bind("SUPER + SHIFT + " .. key, "Move to workspace " .. id, hl.dsp.window.move({ workspace = id }))
  o.bind("SUPER + SHIFT + ALT + " .. key, "Move silently to workspace " .. id, hl.dsp.window.move({ workspace = id, follow = false }))
end

o.bind("SUPER + TAB", "Next workspace", hl.dsp.focus({ workspace = "m+1" }))
o.bind("SUPER + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "m-1" }))
o.bind("SUPER + CTRL + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous_per_monitor" }))
o.bind("SUPER + mouse_down", "Next workspace", hl.dsp.focus({ workspace = "m+1" }))
o.bind("SUPER + mouse_up", "Previous workspace", hl.dsp.focus({ workspace = "m-1" }))

o.bind("SUPER + S", "Scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
o.bind("SUPER + ALT + S", "Move to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

o.bind("CTRL + ALT + TAB", "Next monitor", hl.dsp.focus({ monitor = "+1" }))
o.bind("CTRL + ALT + SHIFT + TAB", "Previous monitor", hl.dsp.focus({ monitor = "-1" }))
o.bind("SUPER + SHIFT + CTRL + LEFT", "Window to left monitor", hl.dsp.window.move({ monitor = "l" }))
o.bind("SUPER + SHIFT + CTRL + RIGHT", "Window to right monitor", hl.dsp.window.move({ monitor = "r" }))

---------------------------------------------------------------------------
-- Clipboard: Super+C/V/X work in terminals too.
---------------------------------------------------------------------------
local function send(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function in_terminal()
  local window = hl.get_active_window()
  for _, tag in ipairs((window and window.tags) or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end
  return false
end

o.bind("SUPER + A", "Select all", send("CTRL", "A"))
o.bind("SUPER + C", "Copy", function()
  if in_terminal() then send("CTRL SHIFT", "C")() else send("CTRL", "C")() end
end)
o.bind("SUPER + V", "Paste", function()
  if in_terminal() then send("CTRL SHIFT", "V")() else send("CTRL", "V")() end
end)
o.bind("SUPER + X", "Cut", send("CTRL", "X"))

---------------------------------------------------------------------------
-- Media, volume, brightness
---------------------------------------------------------------------------
local media = { locked = true }
local media_repeat = { locked = true, repeating = true }
o.bind("XF86AudioRaiseVolume", "Volume up", n("volume-up"), media_repeat)
o.bind("XF86AudioLowerVolume", "Volume down", n("volume-down"), media_repeat)
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", n("volume-up 1"), media_repeat)
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", n("volume-down 1"), media_repeat)
o.bind("XF86AudioMute", "Mute", n("volume-mute"), media)
o.bind("XF86AudioMicMute", "Mute microphone", n("mic-mute"), media)
o.bind("XF86MonBrightnessUp", "Brightness up", n("brightness-up"), media_repeat)
o.bind("XF86MonBrightnessDown", "Brightness down", n("brightness-down"), media_repeat)
o.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", n("brightness-up current 1"), media_repeat)
o.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", n("brightness-down current 1"), media_repeat)
o.bind("XF86KbdBrightnessUp", "Keyboard brightness up", "brightnessctl -d '*kbd_backlight*' set +10%", media_repeat)
o.bind("XF86KbdBrightnessDown", "Keyboard brightness down", "brightnessctl -d '*kbd_backlight*' set 10%-", media_repeat)
o.bind("XF86AudioNext", "Next track", "playerctl next", media)
o.bind("XF86AudioPrev", "Previous track", "playerctl previous", media)
o.bind("XF86AudioPlay", "Play/pause", "playerctl play-pause", media)
o.bind("XF86AudioPause", "Play/pause", "playerctl play-pause", media)

---------------------------------------------------------------------------
-- Zoom
---------------------------------------------------------------------------
o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)
o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)
