extends Node2D

## GDTuner Example — three ways to use the tuner:
##
## 1. AutoTunable (Player node)
##    Drop as child, mark exports with @export_group("tunable").
##    Property binding — sliders set values directly on the node.
##
## 2. UITunable (Title label)
##    Drop as child of any Control. Auto-exposes modulate,
##    theme colors, font sizes, and StyleBox properties.
##
## 3. TunableRegistrar (TorchTuner node)
##    Manual registration — full control over what appears.
##    Game code reads values via DebugTuner.get_value().

@onready var light: PointLight2D = $Light


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	# Manual TunableRegistrar values — read explicitly via get_value()
	light.energy = DebugTuner.get_value("torch/intensity", 1.0)
	light.color = DebugTuner.get_value("torch/color", Color.WHITE)
