extends Node2D

@onready var sprite: Sprite2D = $Sprite
@onready var light: PointLight2D = $Light


func _ready() -> void:
	DebugTuner.value_changed.connect(_on_value_changed)
	DebugTuner.button_pressed.connect(_on_button_pressed)


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return

	light.energy = DebugTuner.get_value("torch/intensity", 1.0)
	light.color = DebugTuner.get_value("torch/color", Color.WHITE)
	sprite.position = DebugTuner.get_value("torch/offset", Vector2(512, 300))
	sprite.visible = DebugTuner.get_value("gameplay/show_sprite", true)


func _on_value_changed(key: String, value: Variant) -> void:
	pass  # Values are read in _process, but you could react here too


func _on_button_pressed(key: String) -> void:
	if key == "gameplay/reset_position":
		sprite.position = Vector2(512, 300)
		light.position = Vector2(512, 300)
