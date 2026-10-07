-- Personal workspace placement rules from the pre-Quattro setup.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

o.window("^(slack)$", { workspace = "10 silent" })
o.window("^(org\\.telegram\\.desktop)$", { workspace = "10 silent" })
o.window("^(chrome-web\\.whatsapp\\.com__-.*)$", { workspace = "10 silent" })
o.window("^(obsidian)$", { workspace = "2 silent" })
o.window(".*[Hh]erdr.*", { workspace = "3 silent" })

-- Preserve the old default-opacity preference while keeping app-specific
-- Quattro exceptions intact.
o.window({ tag = "default-opacity" }, { opacity = "1.0 0.975" })
