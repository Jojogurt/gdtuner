extends Sprite2D

## AutoTunable demo — move with arrow keys.
## Properties inside @export_group("tunable") appear in GDTuner automatically.
## The AutoTunable child node handles registration and property binding.
## Changing a slider sets the property directly — no get_value() needed.

@export_group("tunable")
@export var speed: float = 200.0
@export_range(0.2, 3.0) var size: float = 1.0
@export var tint: Color = Color.CORNFLOWER_BLUE
@export_group("")


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += dir * speed * delta
	scale = Vector2.ONE * size
	modulate = tint
