local wezterm = require("wezterm");
local act = wezterm.action;

local config = {}

if wezterm.config_builder then config = wezterm.config_builder() end

--config.color_scheme = "Argonaut"
config.color_scheme = 'Red Planet'

config.window_background_opacity = 0.98
config.window_decorations = "RESIZE"
config.window_close_confirmation = "AlwaysPrompt"
config.scrollback_lines = 3000
config.default_workspace = "home"


config.font_dirs = { 'fonts' }
config.font_locator = 'ConfigDirsOnly'
config.font = wezterm.font 'VT323'
config.font_size = 18

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

config.status_update_interval = 1000

config.check_for_updates = false

wezterm.on("update-right-status", function (window, pane)
    local ws = window:active_workspace()

    if window:active_key_table() then
        ws = window:active_key_table()
    end

    if window:leader_is_active() then
        ws = "LDR"
    end

    window:set_right_status(wezterm.format({
        { Text = wezterm.nerdfonts.oct_table .. "  " .. ws  },
        { Text = " | "}
    }))
end)

config.inactive_pane_hsb = {
    saturation = 0.7,
    brightness = 0.7
}

--keys
config.leader = {key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
    { key = "a", mods = "LEADER", action = act.SendKey {
        key  = "a", mods = "CTRL"
    } },

    { key = "c", mods = "LEADER", action = act.ActivateCopyMode },

    { key = "-", mods = "LEADER", action = act.SplitVertical {
        domain = "CurrentPaneDomain" }
    },

    { key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal {
        domain = "CurrentPaneDomain" }
    },

    { key = "n", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "e", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "i", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "o", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

    { key = "x", mods = "LEADER", action = act.CloseCurrentPane {
        confirm = true
    } },

    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    { key = "s", mods = "LEADER", action = act.RotatePanes "Clockwise" },

    { key = "r", mods = "LEADER", action = act.ActivateKeyTable {
        name = "resize_pane", one_shot = false
    } },

    { key = "k", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
    { key = "]", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "t", mods = "LEADER", action = act.ShowTabNavigator },

    { key = "m", mods = "LEADER", action = act.ActivateKeyTable {
        name = "move_tab", one_shot = false
    } },

    { key = "w", mods = "LEADER", action = act.ShowLauncherArgs {
        flags = "FUZZY|WORKSPACES"
    } },
}

for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = act.ActivateTab(i - 1)
    })
end

config.key_tables = {
    resize_pane =
    {
        { key = "n", action = act.AdjustPaneSize {
            "Left", 1
        } },
        { key = "e", action = act.AdjustPaneSize {
            "Down", 1
        } },
        { key = "i", action = act.AdjustPaneSize {
            "Up", 1
        } },
        { key = "o", action = act.AdjustPaneSize {
            "Right", 1
        } },
        { key = "Escape", action = "PopKeyTable" },
        { key = "Enter", action = "PopKeyTable" },
    },

    move_tab =
    {
        { key = "n", action = act.MoveTabRelative(-1) },
        { key = "e", action = act.MoveTabRelative(-1) },
        { key = "i", action = act.MoveTabRelative(1) },
        { key = "o", action = act.MoveTabRelative(1) },
        { key = "Escape", action = "PopKeyTable" },
        { key = "Enter", action = "PopKeyTable" },
    }
}

local shell = {
    "cmd", "/k %userprofile%\\.config\\wezterm\\devenv.bat"
}

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
  config.default_prog = shell
end

return config
