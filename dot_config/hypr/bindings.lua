-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Neru mouseless navigation. These compositor bindings avoid granting Neru
-- blanket access to /dev/input while keeping the four modes on one key family.
o.bind("SUPER + semicolon", "Neru: click interface hint", "/usr/bin/neru hints --action left_click")
o.bind("SUPER + SHIFT + semicolon", "Neru: recursive grid", "/usr/bin/neru recursive_grid")
o.bind("SUPER + ALT + semicolon", "Neru: click OCR text hint", "/usr/bin/neru hints --strategy vision --action left_click")
o.bind("SUPER + CTRL + semicolon", "Neru: scroll mode", "/usr/bin/neru scroll --toggle")
