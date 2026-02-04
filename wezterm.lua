local wezterm = require("wezterm");
local act = wezterm.action;

local config = {}

if wezterm.config_builder then config = wezterm.config_builder() end

-- Platform detection
local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_linux = wezterm.target_triple:find("linux") ~= nil
local is_macos = wezterm.target_triple:find("darwin") ~= nil

-- Retro Military color scheme (pale green/orange CRT aesthetic) from Rio
config.colors = {
    foreground = '#a0c4a0',
    background = '#0a0f0a',
    cursor_fg = '#0a0f0a',
    cursor_bg = '#ff9500',
    cursor_border = '#ff9500',
    selection_fg = '#c8e0c8',
    selection_bg = '#1a3320',
    ansi = {
        '#0a0f0a', -- black
        '#ff6b35', -- red
        '#a0c4a0', -- green
        '#ff9500', -- yellow
        '#ff9500', -- blue
        '#ff8c42', -- magenta
        '#7fbf9f', -- cyan
        '#c8e0c8', -- white
    },
    brights = {
        '#2a4a2a', -- bright black
        '#ff8855', -- bright red
        '#c8e0c8', -- bright green
        '#ffaa33', -- bright yellow
        '#ffaa33', -- bright blue
        '#ffaa66', -- bright magenta
        '#a0d8c0', -- bright cyan
        '#d8f0d8', -- bright white
    },
    tab_bar = {
        background = '#0d1a0d',
        active_tab = {
            bg_color = '#ff9500',
            fg_color = '#0a0f0a',
        },
        inactive_tab = {
            bg_color = '#0d1a0d',
            fg_color = '#a0c4a0',
        },
    },
}

-- Window settings from Rio
config.window_background_opacity = 0.95
config.window_decorations = "RESIZE"
config.window_close_confirmation = "AlwaysPrompt"
config.scrollback_lines = 3000
config.default_workspace = "home"

-- Font settings from Rio: Iosevka Term, size 16
config.font = wezterm.font('Iosevka Term', { weight = 'Medium' })
config.font_size = 14
config.font_rules = {
    {
        intensity = 'Bold',
        font = wezterm.font('Iosevka Term', { weight = 'ExtraBold' }),
    },
    {
        italic = true,
        font = wezterm.font('Iosevka Term', { weight = 'Medium', italic = true }),
    },
    {
        italic = true,
        intensity = 'Bold',
        font = wezterm.font('Iosevka Term', { weight = 'ExtraBold', italic = true }),
    },
}

-- Tab bar settings
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true

config.status_update_interval = 1000
config.check_for_updates = false

-- Hide mouse cursor when typing (from Rio)
config.hide_mouse_cursor_when_typing = true

-- Helper to get git branch
local function get_git_branch(cwd)
    if not cwd then return nil end
    local success, stdout, stderr = wezterm.run_child_process({
        "git", "-C", cwd, "branch", "--show-current"
    })
    if success then
        return stdout:gsub("%s+", "")
    end
    return nil
end

-- Helper to get memory usage
local function get_memory_usage()
    if is_windows then
        local success, stdout, stderr = wezterm.run_child_process({
            "powershell", "-NoProfile", "-Command",
            "[math]::Round((Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty FreePhysicalMemory) / 1MB, 1)"
        })
        if success then
            local free_gb = tonumber(stdout:match("([%d.]+)")) or 0
            return string.format("%.1fG free", free_gb)
        end
    else
        -- Linux/macOS: use free command
        local success, stdout, stderr = wezterm.run_child_process({
            "sh", "-c", "free -g | awk '/^Mem:/ {print $7}'"
        })
        if success then
            local free_gb = tonumber(stdout:match("(%d+)")) or 0
            return string.format("%dG free", free_gb)
        end
    end
    return nil
end

-- Helper to get next calendar meeting (Windows/Outlook only)
local function get_next_meeting()
    if not is_windows then return nil end
    local success, stdout, stderr = wezterm.run_child_process({
        "powershell", "-NoProfile", "-Command", [[
try {
    $outlookRunning = Get-Process outlook -ErrorAction SilentlyContinue
    if (-not $outlookRunning) { exit }
    $ol = [Runtime.InteropServices.Marshal]::GetActiveObject("Outlook.Application")
    if ($ol) {
        $ns = $ol.GetNamespace("MAPI")
        $cal = $ns.GetDefaultFolder(9)
        $now = Get-Date
        $endOfDay = $now.Date.AddDays(1)
        $items = $cal.Items
        $items.Sort("[Start]")
        $items.IncludeRecurrences = $true
        $filter = "[Start] >= '" + $now.ToString("g") + "' AND [Start] < '" + $endOfDay.ToString("g") + "'"
        $appts = $items.Restrict($filter)
        if ($appts.Count -gt 0) {
            $next = $appts.GetFirst()
            $start = [DateTime]$next.Start
            $mins = [math]::Round(($start - $now).TotalMinutes)
            if ($mins -lt 0) { $mins = 0 }
            $subj = $next.Subject
            if ($subj.Length -gt 20) { $subj = $subj.Substring(0, 20) }
            Write-Output "$subj|$mins"
        }
    }
} catch { }
]]
    })
    if success and stdout and stdout ~= "" then
        local subject, mins = stdout:match("([^|]+)|(%d+)")
        if subject and mins then
            return {
                subject = subject:gsub("%s+$", ""),
                minutes = tonumber(mins)
            }
        end
    end
    return nil
end

-- Helper to get Docker status (Windows only)
local function get_docker_status()
    if not is_windows then return nil end
    local success, stdout, stderr = wezterm.run_child_process({
        "docker", "info", "--format",
        "{{.ContainersRunning}},{{.ContainersPaused}},{{.ContainersStopped}},{{.Images}}"
    })
    if success then
        local running, paused, stopped, images = stdout:match("(%d+),(%d+),(%d+),(%d+)")
        if running then
            return {
                up = true,
                running = tonumber(running) or 0,
                paused = tonumber(paused) or 0,
                stopped = tonumber(stopped) or 0,
                images = tonumber(images) or 0,
            }
        end
    end
    return { up = false }
end

-- Helper to get local IP address
local function get_ip_address()
    if is_windows then
        local success, stdout, stderr = wezterm.run_child_process({
            "powershell", "-NoProfile", "-Command",
            "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown'} | Select-Object -First 1 -ExpandProperty IPAddress)"
        })
        if success then
            return stdout:gsub("%s+", "")
        end
    else
        -- Linux: use hostname -I
        local success, stdout, stderr = wezterm.run_child_process({
            "sh", "-c", "hostname -I | awk '{print $1}'"
        })
        if success then
            return stdout:gsub("%s+", "")
        end
    end
    return nil
end

-- Cache for expensive operations
local git_cache = { branch = nil, cwd = nil, time = 0 }
local mem_cache = { value = nil, time = 0 }
local ip_cache = { value = nil, time = 0 }
local docker_cache = { value = nil, time = 0 }
local calendar_cache = { value = nil, time = 0 }

wezterm.on("update-right-status", function(window, pane)
    local cells = {}
    local now = os.time()

    -- Leader/key table indicator
    if window:leader_is_active() then
        table.insert(cells, { Foreground = { Color = "#ff9500" } })
        table.insert(cells, { Text = " LDR " })
        table.insert(cells, "ResetAttributes")
    elseif window:active_key_table() then
        table.insert(cells, { Foreground = { Color = "#ff6b35" } })
        table.insert(cells, { Text = " " .. window:active_key_table() .. " " })
        table.insert(cells, "ResetAttributes")
    end

    -- Git branch (cache for 5 seconds)
    local cwd_uri = pane:get_current_working_dir()
    local cwd = cwd_uri and cwd_uri.file_path or nil
    if cwd and (now - git_cache.time > 5 or git_cache.cwd ~= cwd) then
        git_cache.branch = get_git_branch(cwd)
        git_cache.cwd = cwd
        git_cache.time = now
    end
    if git_cache.branch and git_cache.branch ~= "" then
        table.insert(cells, { Foreground = { Color = "#a0c4a0" } })
        table.insert(cells, { Text = wezterm.nerdfonts.dev_git_branch .. " " .. git_cache.branch .. "  " })
        table.insert(cells, "ResetAttributes")
    end

    -- Memory (cache for 10 seconds)
    if now - mem_cache.time > 10 then
        mem_cache.value = get_memory_usage()
        mem_cache.time = now
    end
    if mem_cache.value then
        table.insert(cells, { Foreground = { Color = "#7fbf9f" } })
        table.insert(cells, { Text = wezterm.nerdfonts.md_memory .. " " .. mem_cache.value .. "  " })
        table.insert(cells, "ResetAttributes")
    end

    -- IP address (cache for 60 seconds)
    if now - ip_cache.time > 60 then
        ip_cache.value = get_ip_address()
        ip_cache.time = now
    end
    if ip_cache.value and ip_cache.value ~= "" then
        table.insert(cells, { Foreground = { Color = "#ff8c42" } })
        table.insert(cells, { Text = wezterm.nerdfonts.md_ip_network .. " " .. ip_cache.value .. "  " })
        table.insert(cells, "ResetAttributes")
    end

    -- Docker status (Windows only, cache for 30 seconds)
    -- NOTE: Disabled - docker info can hang. Uncomment to re-enable.
    if false and is_windows then
        if now - docker_cache.time > 30 then
            docker_cache.value = get_docker_status()
            docker_cache.time = now
        end
        if docker_cache.value then
            if docker_cache.value.up then
                local d = docker_cache.value
                local docker_text = string.format("%d/%d", d.running, d.running + d.stopped + d.paused)
                table.insert(cells, { Foreground = { Color = "#2496ed" } })  -- Docker blue
                table.insert(cells, { Text = wezterm.nerdfonts.linux_docker .. " " .. docker_text .. "  " })
                table.insert(cells, "ResetAttributes")
            else
                table.insert(cells, { Foreground = { Color = "#ff6b35" } })  -- Red/orange for down
                table.insert(cells, { Text = wezterm.nerdfonts.linux_docker .. " down  " })
                table.insert(cells, "ResetAttributes")
            end
        end
    end

    -- Next meeting (Windows/Outlook only, cache for 60 seconds)
    -- NOTE: Disabled - Outlook COM can hang. Uncomment to re-enable.
    if false and is_windows then
        if now - calendar_cache.time > 60 then
            calendar_cache.value = get_next_meeting()
            calendar_cache.time = now
        end
        if calendar_cache.value then
            local mtg = calendar_cache.value
            local color = "#a0c4a0"  -- green
            if mtg.minutes <= 5 then
                color = "#ff6b35"  -- red - imminent!
            elseif mtg.minutes <= 15 then
                color = "#ff9500"  -- orange - soon
            end
            local time_str = mtg.minutes .. "m"
            if mtg.minutes >= 60 then
                time_str = string.format("%dh%dm", math.floor(mtg.minutes / 60), mtg.minutes % 60)
            end
            table.insert(cells, { Foreground = { Color = color } })
            table.insert(cells, { Text = wezterm.nerdfonts.md_calendar_clock .. " " .. mtg.subject .. " " .. time_str .. "  " })
            table.insert(cells, "ResetAttributes")
        end
    end

    -- Workspace
    table.insert(cells, { Foreground = { Color = "#ff9500" } })
    table.insert(cells, { Text = wezterm.nerdfonts.oct_table .. " " .. window:active_workspace() .. "  " })
    table.insert(cells, "ResetAttributes")

    -- Time
    table.insert(cells, { Foreground = { Color = "#c8e0c8" } })
    table.insert(cells, { Text = wezterm.strftime("%H:%M:%S") .. " " })

    window:set_right_status(wezterm.format(cells))
end)

config.inactive_pane_hsb = {
    saturation = 0.7,
    brightness = 0.8
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

    -- Window management
    { key = "f", mods = "LEADER", action = act.ToggleFullScreen },
    { key = "F11", action = act.ToggleFullScreen },

    -- Command palette
    { key = "p", mods = "LEADER", action = act.ActivateCommandPalette },

    -- Help menu showing keybindings
    { key = "?", mods = "LEADER|SHIFT", action = act.InputSelector {
        title = "Keybindings (Leader = Ctrl+A)",
        choices = {
            { label = "k       New tab" },
            { label = "[ ]     Prev/Next tab" },
            { label = "1-9     Jump to tab" },
            { label = "t       Tab navigator" },
            { label = "m       Move tab mode (n/o to move)" },
            { label = "-       Split vertical" },
            { label = "|       Split horizontal" },
            { label = "n e i o Navigate panes (Colemak)" },
            { label = "x       Close pane" },
            { label = "z       Zoom pane" },
            { label = "s       Rotate panes" },
            { label = "r       Resize mode (n/e/i/o, Esc to exit)" },
            { label = "c       Copy mode" },
            { label = "w       Workspace switcher" },
            { label = "f       Toggle fullscreen" },
            { label = "p       Command palette" },
            { label = "a       Send Ctrl+A" },
        },
        action = wezterm.action_callback(function() end),
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

-- Shell configuration
if is_windows then
    config.default_prog = { "pwsh", "-NoExit", "-NoLogo" }
end

return config
