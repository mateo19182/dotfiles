-- See https://wiki.hypr.land/Configuring/Window-Rules/
o.window("^(slack|Slack)$", { workspace = "10 silent" })
o.window("^(org\\.telegram\\.desktop)$", { workspace = "10 silent" })
o.window("^(chrome-web\\.whatsapp\\.com__-.*)$", { workspace = "10 silent" })
o.window("^(obsidian)$", { workspace = "2 silent" })

-- Slight transparency on unfocused windows.
o.window(".*", { opacity = "1.0 0.975" })
