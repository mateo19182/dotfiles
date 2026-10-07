-- Change the default Omarchy look'n'feel.

-- Keep tiled windows close together with a slim border.
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 1,
  },
})

-- Personal visual preferences from the pre-Quattro setup.
hl.config({
  decoration = {
    blur = {
      enabled = false,
    },
    rounding = 1,
    dim_inactive = true,
    dim_strength = 0.1,
  },
})

hl.config({
  animations = {
    enabled = false,
  },
})

-- See https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })
