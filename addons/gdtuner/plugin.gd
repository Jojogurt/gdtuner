@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("DebugTuner", "res://addons/gdtuner/debug_tuner.gd")
	add_custom_type(
		"TunableRegistrar", "Node",
		preload("res://addons/gdtuner/tunable_registrar.gd"),
		preload("res://addons/gdtuner/icon.svg")
	)


func _exit_tree() -> void:
	remove_autoload_singleton("DebugTuner")
	remove_custom_type("TunableRegistrar")
