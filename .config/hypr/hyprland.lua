-- Hyprland entry point. Everything lives in ~/.config/hypr (linked from ~/dotfiles).
-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

local home = os.getenv("HOME")

-- Drop cached modules so `hyprctl reload` picks up edits.
for module in pairs(package.loaded) do
  if module == "hypr" or module:sub(1, 5) == "hypr." then
    package.loaded[module] = nil
  end
end
package.path = home .. "/.config/?.lua;" .. package.path

require("hypr.lib")
require("hypr.defaults")
require("hypr.monitors")
require("hypr.input")
require("hypr.looknfeel")
require("hypr.windows")
require("hypr.autostart")
require("hypr.bindings")
