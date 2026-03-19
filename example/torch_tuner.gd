extends TunableRegistrar

## Example TunableRegistrar — demonstrates all control types.


func _init() -> void:
	section_name = "Torch"
	section_id = "torch"


func _register_tunables() -> void:
	add_float("intensity", 0.0, 5.0, 1.0, 0.05)
	add_float("radius", 50.0, 500.0, 200.0, 1.0)
	add_color("color", Color(1.0, 0.9, 0.6, 1.0))
	add_vector2("offset", Vector2(512, 300), Vector2(0, 0), Vector2(1024, 600), 1.0)
	add_bool("flicker", false)
	add_int("flicker_rate", 1, 60, 10)
	add_dropdown("quality", ["Low", "Medium", "High", "Ultra"] as Array[String], 2)
	add_button("reset_position", "Reset Position")
