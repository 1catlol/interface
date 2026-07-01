# Oreo v2
---

## Quick Start

```lua
local Library = loadstring(game:HttpGet("..."))()
local UI = Library.new("My Script")

local mainTab = UI:CreateTab("Main")
local section = UI:CreateSection(mainTab, "Combat", "left")
UI:CreateToggle(section, { name = "Enabled", default = false, flag = "enabled" })
UI:CreateSlider(section, { name = "Speed", default = 10, min = 1, max = 50, step = 1, flag = "speed" })
```

---

## Library.new(title)

| Parameter | Type | Description |
|-----------|------|-------------|
| `title` | string | Window title (default `"cheat.ai"`) |

Creates the main window with the full UI hierarchy. Returns the Library instance.

---

## Core UI Elements

### Library:CreateTab(name)

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Tab name displayed on the tab button |

Creates a new tab with left/right scrollable sections. The first tab is visible by default; switching uses crossfade animations.

Returns: `tabData` — a table with internal tab references. Pass this to `CreateSection` and `CreateMultiTab`.

---

### Library:CreateSection(tab, name, side)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tab` | table | — | Tab or multi-tab data returned by `CreateTab`/`CreateMultiTab` |
| `name` | string | — | Section header text |
| `side` | string | `"left"` | `"left"` or `"right"` — which column to place the section in |

Creates a collapsible-looking section container. All UI elements are added inside sections.

Returns: `sectionData` — pass this as the first argument to element creation functions.

---

### Library:CreateSlider(section, config)

**Config table:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"Slider"` | Label text |
| `default` | number | `50` | Default value |
| `min` | number | `0` | Minimum value |
| `max` | number | `100` | Maximum value |
| `step` | number | `1` | Step increment (`0.5` for decimal, `1` for integer) |
| `flag` | string | auto | Config flag name for save/load |
| `callback` | function | — | Called with `(value)` on change |

```lua
UI:CreateSlider(section, { name = "Smoothness", default = 3, min = 1, max = 20, step = 0.5, flag = "aim_smoothness" })
```

Supports drag interaction, click-to-position, and tweened fill bar.

---

### Library:CreateDropdown(section, config)

**Config table:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"Dropdown"` | Label text |
| `default` | string/table | `""` | Default selected option (single string, or table of strings for multi) |
| `options` | table | `{}` | Array of option strings |
| `multi` | boolean | `false` | Enable multi-select mode |
| `flag` | string | auto | Config flag name |
| `callback` | function | — | Called with `(selected)` — string for single, table for multi |

```lua
-- Single select
UI:CreateDropdown(section, { name = "Target Part", default = "Head", options = {"Head", "Torso", "HRP"}, flag = "aim_part" })

-- Multi select
UI:CreateDropdown(section, {
    name = "Hit Parts", default = {"Head", "Torso"},
    options = {"Head", "Torso", "LeftArm", "RightArm"},
    multi = true, flag = "aim_hitparts",
})
```

Returns: `dropdownData` with a `RefreshOptions(newOptions)` method to dynamically update the option list.

---

### Library:CreateToggle(section, config)

**Config table:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"Toggle"` | Label text |
| `default` | boolean | `false` | Initial toggle state |
| `flag` | string | auto | Config flag name |
| `callback` | function | — | Called with `(value)` on toggle |

```lua
local toggle = UI:CreateToggle(section, { name = "Enabled", default = false, flag = "aim_enabled" })
```

Returns: `toggleData` — supports chained methods described below.

#### Chained Methods on ToggleData

##### toggleData:CreateColorPicker(config)

Adds a color picker chip to the right side of the toggle row.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `default` | Color3 | `Color3.fromRGB(59, 180, 255)` | Default color |
| `flag` | string | `toggleFlag .. "_color"` | Config flag name |
| `callback` | function | — | Called with `(color)` on change |

```lua
toggle:CreateColorPicker({ default = Color3.fromRGB(255, 0, 0), flag = "my_color", callback = function(c) print(c) end })
```

Opens a full HSV color picker popup with saturation/value square and hue slider.

##### toggleData:CreateKeybind(config)

Adds a keybind chip to the right side. Supports keyboard keys and mouse buttons (MB1/MB2/MB3).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `default` | string | `"E"` | Default key name (e.g. `"E"`, `"MouseButton1"`) |
| `mode` | string | `"Toggle"` | `"Toggle"`, `"Hold"`, or `"Always"` |
| `flag` | string | `toggleFlag .. "_keybind"` | Config flag name |
| `callback` | function | — | Called with `(key, mode)` on rebind |

```lua
local toggle = UI:CreateToggle(section, { name = "Aimbot", flag = "aim_enabled" })
toggle:CreateKeybind({ default = "E", mode = "Hold", flag = "aim_key" })

-- Check if keybind is active:
if toggle:IsActive() then
    -- aimbot logic
end
```

**Interaction:**
- **Left-click** the keybind button → press any keyboard key or mouse button to bind. Backspace to unbind (`[N/A]`).
- **Right-click** the keybind button → opens mode selector (Hold/Toggle/Always).

Mouse buttons display as `MB1`, `MB2`, `MB3` in the UI.

##### toggleData:IsActive()

Returns `true` when the bound key is pressed (Hold mode held, Toggle mode toggled on, or Always mode).

##### toggleData:AddContextMenu()

Adds a three-dot menu button that opens a popup. Returns a `ctxSection` that you can use like a section — call `CreateSlider`, `CreateToggle`, etc. on it.

```lua
local ctx = toggle:AddContextMenu()
UI:CreateSlider(ctx, { name = "Timeout", default = 2, min = 0, max = 10, step = 0.5, flag = "timeout" })
UI:CreateToggle(ctx, { name = "Wallbang", default = false, flag = "wallbang" })
ctx.Close() -- programmatically close
```

---

### Library:CreateTextBox(section, config)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"TextBox"` | Internal name |
| `default` | string | `""` | Default text |
| `placeholder` | string | `"Config name...."` | Placeholder text |
| `flag` | string | auto | Config flag name |
| `callback` | function | — | Called with `(text, enterPressed)` on focus lost |

```lua
UI:CreateTextBox(section, { placeholder = "Search...", flag = "search", callback = function(text, enter) print(text) end })
```

---

### Library:CreateButton(section, config)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"Button"` | Button text |
| `callback` | function | — | Called on click |

Has a click flash animation (tweens to accent color and back).

```lua
UI:CreateButton(section, { name = "Execute", callback = function() print("clicked") end })
```

---

### Library:CreateLabel(section, text)

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | string | Display text (supports RichText) |

```lua
UI:CreateLabel(section, "Welcome to the script!")
```

---

### Library:CreateWarning(title, text, callback)

| Parameter | Type | Description |
|-----------|------|-------------|
| `title` | string | Title (currently unused by the dialog) |
| `text` | string | Warning message text |
| `callback` | function | Called with `(accepted)` — `true` if "Okay", `false` if "No" |

Shows a modal warning dialog with Okay/No buttons.

```lua
UI:CreateWarning("Confirm", "Are you sure you want to close?", function(accepted)
    if accepted then print("User said okay") end
end)
```

---

## Multi-Tabs

### Library:CreateMultiTab(tab, name)

| Parameter | Type | Description |
|-----------|------|-------------|
| `tab` | table | Parent tab data from `CreateTab` |
| `name` | string | Multi-tab button text |

Creates a sub-tab system within a parent tab. The first multi-tab is active by default.
Switching uses smooth GroupTransparency crossfades.

Returns: `mtData` — pass this to `CreateSection` just like a regular tab.

```lua
local combatSub = UI:CreateMultiTab(mainTab, "Combat")
local espSub = UI:CreateMultiTab(mainTab, "ESP")

local aimSection = UI:CreateSection(combatSub, "Aimbot", "left")
```

---

## Keybind Panel

### Library:RegisterKeybindLabel(flag, displayName)

| Parameter | Type | Description |
|-----------|------|-------------|
| `flag` | string | The flag used in `CreateKeybind` |
| `displayName` | string | Human-readable name shown in the panel |

Registers a keybind to appear in the keybind list panel. The panel auto-updates every frame (only when visible), showing `[KEY] Name` in accent color when active, gray when inactive.

```lua
toggle:CreateKeybind({ default = "E", mode = "Hold", flag = "aim_key" })
UI:RegisterKeybindLabel("aim_key", "Aimbot")
```

### Library:ShowKeybinds(visible)

Shows or hides the keybind panel (positioned on the left side of the screen).

```lua
UI:ShowKeybinds(true)
```

---

## Config System

All configs are stored as JSON files in the `cheat_ai/` workspace folder with automatic Color3 serialization.

### Library:SaveConfig(name)

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Config name (saved as `cheat_ai/name.json`) |

Saves all current flag values. Also writes the name to `_last.txt` for auto-load.

### Library:LoadConfig(name)

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Config name to load |

Loads flag values from a saved config and calls `RefreshAll()`. Returns `true` on success, `false` if not found.

### Library:LoadLastConfig()

Loads the last saved config (from `_last.txt`). Returns `true`/`false`.

### Library:GetConfigs()

Returns an array of saved config names (without `.json` extension).

### Library:DeleteConfig(name)

Deletes a saved config file.

### Library:RefreshAll()

Re-applies all synced flags to their UI elements. Called automatically by `LoadConfig`.

---

## Notifications

### Library:Notify(text, isWarning)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `text` | string | — | Notification message |
| `isWarning` | boolean | `false` | Warning style (yellow) vs normal (blue accent) |

Shows a slide-in notification with a 3-second timer bar that auto-dismisses.

```lua
UI:Notify("Config saved!", false)
UI:Notify("Failed to inject!", true)
```

---

## Menu Control

### Library:Toggle()

Shows/hides the main window with bounce animation.

### Library:SetVisible(visible)

Explicitly show or hide the main window.

### Library:Destroy()

Destroys all UI elements and disconnects all input connections. Clean shutdown.

### Library:Unload()

Calls `Destroy()` then fires the `OnUnload` callback.

### Library:OnUnload(callback)

Sets a callback that runs when `Unload()` is called.

### Library:SetMenuKeybind(key)

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | Enum.KeyCode | Roblox KeyCode enum (default `Insert`) |

Changes the keybind that opens/closes the menu.

```lua
UI:SetMenuKeybind(Enum.KeyCode.RightShift)
```

---

## Global State

### Library.flags

A table containing all current flag values. Accessible anywhere:

```lua
print(Library.flags.aim_enabled)          -- boolean
print(Library.flags.aim_smoothness)       -- number
print(Library.flags.aim_part)             -- string
print(Library.flags.aim_key)              -- {key = "E", mode = "Hold", active = false}
print(Library.flags.aim_hitparts)         -- table of strings (multi dropdown)
print(Library.flags.aim_vischeck_color)   -- Color3
```

---

## Complete Example

```lua
local Library = loadstring(game:HttpGet("..."))()
local UI = Library.new("My Cheat")
UI:SetMenuKeybind(Enum.KeyCode.Insert)
UI:LoadLastConfig()

-- Tabs
local mainTab = UI:CreateTab("Main")
local visualsTab = UI:CreateTab("Visuals")
local settingsTab = UI:CreateTab("Settings")

-- Multi-tabs within Main
local combatSub = UI:CreateMultiTab(mainTab, "Combat")
local miscSub = UI:CreateMultiTab(mainTab, "Misc")

-- Combat sub-tab: left side
local aimSection = UI:CreateSection(combatSub, "Aimbot", "left")
UI:CreateSlider(aimSection, { name = "Smoothness", default = 3, min = 1, max = 20, step = 0.5, flag = "aim_smooth" })
UI:CreateSlider(aimSection, { name = "FOV", default = 150, min = 20, max = 500, step = 5, flag = "aim_fov" })
UI:CreateDropdown(aimSection, { name = "Target", default = "Head", options = {"Head", "Torso", "HRP"}, flag = "aim_part" })

local aimToggle = UI:CreateToggle(aimSection, { name = "Enabled", default = false, flag = "aim_enabled" })
aimToggle:CreateKeybind({ default = "MouseButton2", mode = "Hold", flag = "aim_key" })
aimToggle:CreateColorPicker({ default = Color3.fromRGB(255, 0, 0), flag = "aim_color" })
UI:RegisterKeybindLabel("aim_key", "Aimbot")

-- Right side
local miscRight = UI:CreateSection(combatSub, "Settings", "right")
UI:CreateToggle(miscRight, { name = "Auto Fire", default = false, flag = "autofire" })
UI:CreateToggle(miscRight, { name = "Silent Aim", default = true, flag = "silent" })

-- Visuals tab
local espSection = UI:CreateSection(visualsTab, "ESP", "left")
local boxToggle = UI:CreateToggle(espSection, { name = "Box ESP", default = false, flag = "esp_box" })
boxToggle:CreateColorPicker({ default = Color3.fromRGB(255, 255, 255), flag = "esp_box_color" })
boxToggle:CreateKeybind({ default = "V", mode = "Toggle", flag = "esp_box_key" })
UI:RegisterKeybindLabel("esp_box_key", "Box ESP")

local ctx = boxToggle:AddContextMenu()
UI:CreateSlider(ctx, { name = "Thickness", default = 1, min = 1, max = 5, step = 1, flag = "esp_box_thick" })
UI:CreateToggle(ctx, { name = "Filled", default = false, flag = "esp_box_filled" })

UI:CreateToggle(espSection, { name = "Tracers", default = false, flag = "esp_tracers" })
UI:CreateToggle(espSection, { name = "Health Bar", default = true, flag = "esp_health" })

-- Settings tab
local cfgSection = UI:CreateSection(settingsTab, "Config", "left")
UI:CreateTextBox(cfgSection, { placeholder = "Config name...", flag = "cfg_name" })
UI:CreateButton(cfgSection, { name = "Save Config", callback = function()
    local name = Library.flags.cfg_name
    if name ~= "" then
        UI:SaveConfig(name)
        UI:Notify("Saved: " .. name)
    end
end})
UI:CreateButton(cfgSection, { name = "Load Config", callback = function()
    local name = Library.flags.cfg_name
    if name ~= "" then
        local ok = UI:LoadConfig(name)
        UI:Notify(ok and "Loaded: " .. name or "Not found: " .. name, not ok)
    end
end})

-- Keybind panel
UI:ShowKeybinds(true)

-- Unload hook
UI:OnUnload(function()
    print("UI closed, cleaning up...")
end)

-- Game loop example
game:GetService("RunService").RenderStepped:Connect(function()
    if aimToggle:IsActive() then
        -- aimbot active via keybind
    end
end)
```

---

## Architecture Notes

- **Flags**: All element values are stored in the global `Library.flags` table, keyed by their `flag` name. The config system serializes/deserializes this table.
- **Mobile**: Auto-detected via `UserInputService.TouchEnabled`. Shows UI toggle and lock buttons in bottom-right corner when on mobile.
