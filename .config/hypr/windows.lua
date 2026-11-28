-- See https://wiki.hypr.land/Configuring/Window-Rules/
o.window("^(slack|Slack)$", { workspace = "10 silent" })
o.window("^(org\\.telegram\\.desktop)$", { workspace = "10 silent" })
o.window("^(chrome-web\\.whatsapp\\.com__-.*)$", { workspace = "10 silent" })
o.window("^(obsidian|md\\.obsidian\\.Obsidian)$", { workspace = "2 silent" })
o.window("^(com\\.t3tools\\.T3Code)$", { workspace = "1 silent" })
o.window("^(AWS VPN Client)$", { workspace = "4 silent" })
o.window("^(chrome-(gmail\\.com|mail\\.google\\.com|calendar\\.google\\.com)__-.*)$", { workspace = "8 silent" })

-- Slight transparency on unfocused windows.
o.window(".*", { opacity = "1.0 0.975" })
