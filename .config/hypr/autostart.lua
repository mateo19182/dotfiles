-- Noctalia, Hex, hypridle, udiskie and syncthing start as systemd user services
-- with the graphical session. Apps below open once per login on fixed workspaces;
-- apps with their own window class are placed by rules in windows.lua.

local apps = {
  "t3code-desktop",
  "obsidian",
  "aws-vpn-client-gui",
  "slack",
  "Telegram",
}

local webapps = {
  "https://web.whatsapp.com/",
  "https://calendar.google.com/",
  "https://gmail.com",
}

-- All Chrome profiles share class `google-chrome`, so each one is placed in
-- launch order: open the next once the previous window has been moved.
local profiles = {
  { dir = "Profile 2", workspace = "3" }, -- Tribo
  { dir = "Default", workspace = "4" }, -- Zepo
  { dir = "Profile 1", workspace = "9" }, -- Mateo
}

local function open_profile(profile)
  hl.exec_cmd(o.launch("google-chrome-stable --profile-directory=" .. o.sh(profile.dir)))
end

hl.on("hyprland.start", function()
  for _, command in ipairs(apps) do
    hl.exec_cmd(o.launch(command))
  end

  local pending = 1
  local subscription
  subscription = hl.on("window.open", function(window)
    if not window or window.class ~= "google-chrome" or not profiles[pending] then
      return
    end
    hl.dispatch(hl.dsp.window.move({
      workspace = profiles[pending].workspace,
      follow = false,
      window = "address:" .. window.address,
    }))
    pending = pending + 1
    if profiles[pending] then
      open_profile(profiles[pending])
    else
      subscription:remove()
      -- Webapps last, once Chrome's main process is up.
      for _, url in ipairs(webapps) do
        hl.exec_cmd(o.webapp(url))
      end
    end
  end)
  open_profile(profiles[1])
end)
