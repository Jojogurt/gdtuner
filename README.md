<img src="icon.png" alt="GDTUNER" width="256">

# GDTUNER

Live-tuning developer tool for Godot 4 — tweak game parameters through a separate window with slider, checkbox, color picker, dropdown, vector, and button controls.

Press **F12** to toggle the tuner window. On mobile, **shake the device** twice to toggle. All controls are no-op in release builds (zero cost).

## Installation

### Manual

1. Copy `addons/gdtuner/` into your project's `addons/` folder
2. In the editor: **Project > Project Settings > Plugins** — enable **gdtuner**
3. The plugin automatically registers `DebugTuner` as an autoload

### CLI

```bash
cp -r /path/to/gdtuner/addons/gdtuner /path/to/my-game/addons/gdtuner
cd /path/to/my-game
godot --headless --script addons/gdtuner/installer.gd
```

## Quick Start — AutoTunable (recommended)

The fastest way to make any property tunable. Zero boilerplate.

### 1. Mark exports as tunable

```gdscript
@export_group("tunable")
@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export var god_mode: bool = false
@export_group("")
```

### 2. Add AutoTunable child

In your `_ready()`:

```gdscript
func _ready():
    var tuner := AutoTunable.new()
    tuner.section_name = "Player"
    tuner.section_id = "player"
    add_child(tuner)
```

Or add an AutoTunable node in the scene tree via the editor.

### 3. That's it

Read properties directly as `self.speed` — no `get_value()` needed. When you drag a slider, AutoTunable calls `node.set("speed", value)` on the parent, which triggers any setter you've defined.

### Reactive setters

For properties that need side effects (redraw, recalculate, forward to child nodes):

```gdscript
@export_group("tunable")
@export var tile_size: float = 88.0:
    set(v):
        tile_size = v
        if is_inside_tree():
            _recompute_grid()
            queue_redraw()
@export var light_color: Color = Color.WHITE:
    set(v):
        light_color = v
        if _light:
            _light.color = v
@export_group("")
```

### Range hints

AutoTunable auto-generates slider ranges from the current value (`[0, value * 3]`). Override with:

- **`@export_range`** — respected automatically:
  ```gdscript
  @export_range(0.0, 500.0, 1.0) var speed: float = 200.0
  ```
- **Metadata** — for fine control:
  ```gdscript
  func _ready():
      set_meta("tunable_range_speed", Vector2(0, 1000))
  ```

### Supported types

`float`, `int`, `bool`, `Color`, `Vector2`, `Vector3`

## UITunable

Drop as child of any **Control** node to auto-expose visual properties with zero code:

- `modulate`, `self_modulate`, `custom_minimum_size`
- Theme override colors and font sizes
- StyleBoxFlat properties: `bg_color`, `border_color`, `corner_radius`, `border_width`

```gdscript
func _ready():
    var ui_tuner := UITunable.new()
    add_child(ui_tuner)
```

## TunableRegistrar (legacy)

Manual registration with explicit ranges. Still supported.

```gdscript
extends TunableRegistrar

func _init() -> void:
    section_name = "Player"

func _register_tunables() -> void:
    add_float("speed", 0.0, 500.0, 200.0, 1.0)
    add_bool("god_mode", false)
```

Read values with `DebugTuner.get_value("player/speed", 200.0)`.

## API Reference

### DebugTuner (autoload)

| Method | Description |
|--------|-------------|
| `get_value(key, fallback)` | Returns tuned value, or fallback if key doesn't exist. Safe in release builds. |
| `toggle_window()` | Show/hide the tuner window (also bound to F12). |
| `copy_all_values_to_clipboard()` | Copies all current values as text to clipboard. |
| `get_all_values_as_string()` | Returns all current values as a formatted string. |
| `bake_all_values()` | Rewrites default values in your GDScript source files to match current tuned values. |

| Signal | Description |
|--------|-------------|
| `value_changed(key, value)` | Emitted when any control value changes (fires during drag). |
| `button_pressed(key)` | Emitted when an action button is pressed. |

### AutoTunable (Node)

Drop as child of any node. Scans parent for `@export_group("tunable")` variables and registers them automatically.

| Export | Description |
|--------|-------------|
| `section_name` | Display name in tuner UI (defaults to parent node name) |
| `section_id` | Key prefix, e.g. `"player"` → keys are `"player/speed"` (auto-generated from name if empty) |

### UITunable (Node)

Drop as child of any Control. Auto-exposes visual properties (modulate, theme overrides, StyleBoxFlat).

| Export | Description |
|--------|-------------|
| `section_name` | Display name in tuner UI |
| `section_id` | Key prefix (auto-generated with `ui_` prefix if empty) |

### TunableRegistrar (Node) — legacy

Override `_register_tunables()` and use these methods:

| Method | Parameters |
|--------|------------|
| `add_float(key, min, max, default, step=0.01)` | Float slider |
| `add_int(key, min, max, default, step=1)` | Integer slider |
| `add_bool(key, default)` | Checkbox |
| `add_color(key, default)` | Color picker |
| `add_dropdown(key, options, default_index=0)` | Dropdown menu |
| `add_vector2(key, default, min, max, step=1.0)` | Two-axis slider |
| `add_vector3(key, default, min, max, step=1.0)` | Three-axis slider |
| `add_button(key, label)` | Action button |

## Bake to Source

Click **Bake to Source** in the tuner window to rewrite default values directly in your GDScript files.

For `@export var` (AutoTunable):
```gdscript
# Before
@export var intensity: float = 1.0
# After bake
@export var intensity: float = 1.35
```

For `add_float()` (TunableRegistrar):
```gdscript
# Before
add_float("intensity", 0.0, 5.0, 1.0, 0.05)
# After bake
add_float("intensity", 0.0, 5.0, 1.35, 0.05)
```

Works with setter exports too (`@export var speed: float = 5.0:`).

## Usage with Claude Code

Use **Copy All Values** and paste into Claude Code:

1. Run your game, press F12 to open the tuner
2. Adjust sliders/controls until the game feels right
3. Click **Copy All Values** at the bottom of the tuner window
4. Paste into Claude Code with: *"use these values as the new defaults"*

Output format:

```
# gdtuner values — 2025-01-15 14:32:07
player/speed = 220.0
player/jump_force = 450.0
torch/color = Color(1, 0.8, 0.3, 1)
```

## UI Modes

| Mode | Trigger | When |
|------|---------|------|
| Editor bottom panel | Automatic | Running from editor with debugger |
| Separate window | F12 | Desktop standalone |
| Bottom sheet | Shake device (2x) | iOS / Android |

## Multiple Instances

Multiple nodes with the same `section_id` share one section in the tuner. The section stays visible as long as at least one instance is in the scene tree. Useful for e.g. 10 torch instances sharing the same "torch/intensity" slider.

## Release Builds

All gdtuner code is gated by `OS.is_debug_build()`. In release:
- AutoTunable/UITunable: `_ready()` returns immediately, no signals connected
- DebugTuner: all methods return early or return fallback values
- No UI created, no processing, zero runtime cost

## Requirements

- Godot 4.3+
- Pure GDScript, no external dependencies
- MIT License
