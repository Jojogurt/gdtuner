<img src="icon.png" alt="GDTUNER" width="256">

# GDTUNER

Live-tuning developer tool for Godot 4 — tweak game parameters through a separate window with slider, checkbox, color picker, dropdown, vector, and button controls.

Press **F12** to toggle the tuner window. All controls are no-op in release builds (zero cost).

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

## Quick Start

### 1. Create a tuner script

```gdscript
extends TunableRegistrar

func _init() -> void:
    section_name = "Player"

func _register_tunables() -> void:
    add_float("speed", 0.0, 500.0, 200.0, 1.0)
    add_float("jump_force", 0.0, 1000.0, 400.0, 5.0)
    add_bool("god_mode", false)
```

### 2. Add as child of your scene

Attach the script to a Node and add it as a child of any scene. Controls appear when the scene enters the tree and disappear when it exits.

### 3. Read values

```gdscript
func _process(delta: float) -> void:
    var speed = DebugTuner.get_value("player/speed", 200.0)
    var god = DebugTuner.get_value("player/god_mode", false)
```

Or react to changes via signal:

```gdscript
func _ready() -> void:
    DebugTuner.value_changed.connect(_on_tuner_changed)

func _on_tuner_changed(key: String, value: Variant) -> void:
    if key == "player/speed":
        velocity_component.max_speed = value
```

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

### TunableRegistrar (Node)

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

**Exports:** `section_name` (display name), `section_id` (auto-generated from name if empty).

## Bake to Source

Click **Bake to Source** in the tuner window to rewrite the default values directly in your GDScript files. No copy-paste needed.

Before:
```gdscript
add_float("intensity", 0.0, 5.0, 1.0, 0.05)
add_color("color", Color(1, 1, 1, 1))
```

After baking with tuned values:
```gdscript
add_float("intensity", 0.0, 5.0, 1.35, 0.05)
add_color("color", Color(1, 0.8, 0.3, 1))
```

All control types are supported: float, int, bool, color, dropdown, vector2, vector3.

## Usage with Claude Code

Alternatively, use **Copy All Values** and paste into Claude Code:

1. Run your game, press F12 to open the tuner
2. Adjust sliders/controls until the game feels right
3. Click **Copy All Values** at the bottom of the tuner window
4. Paste into Claude Code with: *"use these values as the new defaults"*

Output format:

```
# gdtuner values — 2025-01-15 14:32:07
torch/intensity = 1.35
torch/radius = 280.0
torch/color = Color(1, 0.8, 0.3, 1)
gameplay/move_speed = 0.15
```

## Controls Reference

| Control | Method | UI | Description |
|---------|--------|----|-------------|
| Float Slider | `add_float()` | Label + value + HSlider + reset | Continuous float value, emits during drag |
| Int Slider | `add_int()` | Label + value + HSlider + reset | Integer value with step |
| Checkbox | `add_bool()` | Label + CheckBox + reset | Boolean toggle |
| Color | `add_color()` | Label + ColorPickerButton + reset | Color with full picker popup |
| Dropdown | `add_dropdown()` | Label + OptionButton + reset | String selection from list |
| Vector2 | `add_vector2()` | Label + reset, 2x axis sliders | Two-component vector |
| Vector3 | `add_vector3()` | Label + reset, 3x axis sliders | Three-component vector |
| Button | `add_button()` | Button in FlowContainer | Action trigger, emits `button_pressed` signal |

Every control (except Button) has a reset button (**↺**) that restores the default value and emits the change signal.

## Multiple Instances

Multiple nodes with the same `section_id` share one section in the tuner. The section stays visible as long as at least one instance is in the scene tree. This is useful for e.g. 10 torch instances that should all respond to the same "torch/intensity" slider.

## Console Output

Every value change is logged:

```
[gdtuner] torch/intensity = 1.35
[gdtuner] torch/color = Color(1, 0.8, 0.3, 1)
[gdtuner] gameplay/show_grid = true
```

Button presses:

```
[gdtuner:action] gameplay/reset_position pressed
```

## Requirements

- Godot 4.3+
- Pure GDScript, no external dependencies
- MIT License
