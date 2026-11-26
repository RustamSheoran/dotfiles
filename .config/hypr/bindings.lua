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
-- hl.unbind("F3")
hl.unbind("END")
-- End → Screenshot
o.bind("END", "Screenshot", "omarchy-capture-screenshot")

-- Music Player (rmpc): start mpd on-demand, focus if already open, prefer foot
o.bind("SUPER + M", "Music Player", "bash -c 'systemctl --user is-active --quiet mpd || systemctl --user start mpd; if hyprctl clients -j | jq -e \".[] | select(.class == \\\"rmpc\\\")\" >/dev/null 2>&1; then hyprctl dispatch focuswindow class:rmpc; elif command -v foot >/dev/null 2>&1; then foot --app-id=rmpc -e rmpc; else xdg-terminal-exec -e rmpc; fi'")

-- Tmux
o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })

-- Restored preinstalled bindings
o.bind("SUPER + SHIFT + Q", "Calculator", "omacalc")
o.bind("XF86Calculator", "Calculator", "omacalc")
o.bind("SUPER + SHIFT + M", "Music", { omarchy = "spotify" })
o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end
