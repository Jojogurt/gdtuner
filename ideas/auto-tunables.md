# Auto-Tunables — automatic variable registration

## Problem
Currently TunableRegistrar requires manual code to register each variable.
UI-related properties especially could be auto-detected.

## Approaches

### 1. Auto-scan @export variables
New node `AutoTunable` — drop as child of any node, scans parent via
`get_property_list()` and registers all @export vars as tuner controls.

- Pro: zero boilerplate, works with existing code
- Con: too many variables (noise), needs filtering

### 2. @export_group("tunable") as marker
User marks a group of exports:

```gdscript
@export_group("tunable")
@export var speed: float = 5.0
@export var jump_force: float = 10.0
@export_group("")
```

AutoTunable scans only exports in the "tunable" group. Gives control over
what appears while requiring zero separate registration code.

### 3. Auto UI Tuner — specifically for Control nodes
Dedicated `UITunable` node — drop as child of any Control and it
automatically exposes:
- modulate / self_modulate (Color)
- custom_minimum_size (Vector2)
- Theme overrides: colors, font sizes, margins
- StyleBox properties: bg_color, corner_radius, border_width

Most useful for UI tweaking — zero code, drop node, see all visual properties.

### 4. Metadata via doc comments

```gdscript
@export var speed: float = 5.0  ## @tunable
```

Parser looks for `## @tunable` in doc comments and auto-registers.
Cleanest but requires source parsing.

## Recommended combo
**Option 2 + 3 together:**
- `@export_group("tunable")` for logic — opt-in, controlled, zero extra code
- `UITunable` node for UI — zero code, drag-and-drop on any Control

## Range strategy for UITunable

### Default heuristics by property type

| Property type     | Range                  | Step          |
|-------------------|------------------------|---------------|
| Color (modulate, theme colors) | full 0-1 per channel (ColorPicker) | n/a |
| Font size (int)   | [1, current * 3]       | 1             |
| Margins / min_size | [0, current * 3] or [0, 500] | 1       |
| corner_radius     | [0, 100]               | 1             |
| border_width      | [0, 50]                | 1             |
| Float properties  | [0, current * 3]       | 0.01 * range  |

General formula: `[0, current_value * 3]` covers ~90% of cases with no config.

### Per-property override via metadata

If heuristic doesn't fit, user can set meta on the Control node:

```gdscript
func _ready():
    set_meta("tunable_range_font_size", Vector2(8, 72))
```

UITunable checks `get_meta("tunable_range_<property>")` first, falls back
to heuristic if not set.

### Dynamic range expansion

When slider reaches max, auto-expand range (double it) — similar to how
the Godot Inspector handles unbounded numeric properties. Could also add
an "expand range" button per control.

## Property binding — zero-code integration

### The problem with current API

Current TunableRegistrar requires the game to actively cooperate:

```gdscript
# Game code must change to read from tuner:
var speed = DebugTuner.get_value("player/speed", 5.0)
```

This means gdtuner can't be dropped into an existing project — code changes
are required everywhere a tunable value is used.

### Property binding approach

Instead of the game polling `get_value()`, the tuner directly sets
properties on target nodes via `node.set(property, value)`:

- Tuner scans node for @export properties (via `get_property_list()`)
- Creates controls with current values and heuristic ranges
- When user changes a slider, tuner calls `node.set("speed", new_value)`
- Game reads `self.speed` as normal — no awareness of tuner needed

### Why this works

`@export` variables in Godot are full properties with getters/setters.
Changing them via `node.set()` is equivalent to changing them in the
Inspector. If the game logic reads `self.speed`, it gets the tuned value
automatically.

### Comparison

| Approach                      | Code changes? | Drop-in? |
|-------------------------------|---------------|----------|
| TunableRegistrar (current)    | Yes — get_value() everywhere | No |
| Property binding + auto-scan  | No            | Yes      |
| UITunable (Control props)     | No            | Yes      |

### Implementation priority

Property binding + @export_group("tunable") filtering is the highest
value feature — makes gdtuner a true drop-in tool for any project.
