extends Node

## Central manager for gdtuner. Registered as autoload singleton "DebugTuner".
## Creates and manages a separate Window with tuning controls.
## In release builds, all operations are no-ops with zero cost.

signal value_changed(key: String, value: Variant)
signal button_pressed(key: String)

var _is_debug: bool = false
var _window: Window = null
var _scroll: ScrollContainer = null
var _main_vbox: VBoxContainer = null
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _sections: Dictionary = {}  # section_id -> { display_name, container, header, ref_count, controls }
var _control_nodes: Dictionary = {}  # full_key -> control node
var _control_configs: Dictionary = {}  # full_key -> config dict
var _section_scripts: Dictionary = {}  # section_id -> script res:// path


func _ready() -> void:
	_is_debug = OS.is_debug_build()
	if not _is_debug:
		return
	_create_window()


func _input(event: InputEvent) -> void:
	if not _is_debug:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			toggle_window()


# --- Public API ---

func get_value(key: String, fallback: Variant = null) -> Variant:
	if not _is_debug:
		return fallback
	return _values.get(key, fallback)


func toggle_window() -> void:
	if not _is_debug or _window == null:
		return
	_window.visible = not _window.visible


func register_section(section_id: String, display_name: String, script_path: String = "") -> void:
	if not _is_debug:
		return
	if not script_path.is_empty():
		_section_scripts[section_id] = script_path
	if _sections.has(section_id):
		_sections[section_id].ref_count += 1
		return
	var section_data := {
		"display_name": display_name,
		"container": null,
		"header": null,
		"content": null,
		"ref_count": 1,
		"controls": [],
		"collapsed": false,
	}
	_build_section_ui(section_id, section_data)
	_sections[section_id] = section_data


func register_control(section_id: String, key: String, config: Dictionary) -> void:
	if not _is_debug:
		return
	var full_key := section_id + "/" + key
	if _control_nodes.has(full_key):
		return
	var default_value: Variant = config.get("default")
	_defaults[full_key] = default_value
	if not _values.has(full_key):
		_values[full_key] = default_value
	_control_configs[full_key] = config
	var control_type: String = config.get("type", "")
	var control_node: Control = null
	match control_type:
		"float", "int":
			control_node = _create_slider_control(full_key, config)
		"bool":
			control_node = _create_checkbox_control(full_key, config)
		"color":
			control_node = _create_color_control(full_key, config)
		"dropdown":
			control_node = _create_dropdown_control(full_key, config)
		"vector2":
			control_node = _create_vector2_control(full_key, config)
		"vector3":
			control_node = _create_vector3_control(full_key, config)
		"button":
			control_node = _create_button_control(full_key, config)
	if control_node == null:
		return
	_control_nodes[full_key] = control_node
	if _sections.has(section_id):
		var section_data: Dictionary = _sections[section_id]
		if control_type == "button":
			var flow: FlowContainer = _get_or_create_button_flow(section_data)
			flow.add_child(control_node)
		else:
			section_data.content.add_child(control_node)
		section_data.controls.append(full_key)


func unregister_section(section_id: String) -> void:
	if not _is_debug:
		return
	if not _sections.has(section_id):
		return
	var section_data: Dictionary = _sections[section_id]
	section_data.ref_count -= 1
	if section_data.ref_count <= 0:
		for ctrl_key in section_data.controls:
			_control_nodes.erase(ctrl_key)
		if section_data.container != null:
			section_data.container.queue_free()
		_sections.erase(section_id)


func copy_all_values_to_clipboard() -> void:
	if not _is_debug:
		return
	DisplayServer.clipboard_set(get_all_values_as_string())
	print("[gdtuner] Values copied to clipboard")


func get_all_values_as_string() -> String:
	var lines: PackedStringArray = []
	var datetime := Time.get_datetime_dict_from_system()
	lines.append("# gdtuner values — %04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	])
	var keys := _values.keys()
	keys.sort()
	for key in keys:
		var val: Variant = _values[key]
		lines.append("%s = %s" % [key, _format_value(val)])
	return "\n".join(lines)


# --- Window Creation ---

func _create_window() -> void:
	_window = Window.new()
	_window.title = "gdtuner"
	_window.size = Vector2i(380, 650)
	_window.unfocusable = true
	_window.always_on_top = true
	_window.wrap_controls = true
	_window.visible = false
	_window.close_requested.connect(_on_window_close_requested)
	_position_window()

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	margin.add_child(outer_vbox)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(_scroll)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_main_vbox)

	var btn_row := HBoxContainer.new()
	outer_vbox.add_child(btn_row)

	var copy_btn := Button.new()
	copy_btn.text = "Copy All Values"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.pressed.connect(copy_all_values_to_clipboard)
	btn_row.add_child(copy_btn)

	var bake_btn := Button.new()
	bake_btn.text = "Bake to Source"
	bake_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bake_btn.pressed.connect(bake_all_values)
	btn_row.add_child(bake_btn)

	add_child(_window)


func _position_window() -> void:
	var screen_size := DisplayServer.screen_get_size()
	_window.position = Vector2i(screen_size.x - _window.size.x - 50, 50)


func _on_window_close_requested() -> void:
	_window.visible = false


# --- Section UI ---

func _build_section_ui(section_id: String, section_data: Dictionary) -> void:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := Button.new()
	header.text = "  %s" % section_data.display_name
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	style.content_margin_left = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	header.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	header.add_theme_stylebox_override("hover", hover_style)
	header.add_theme_stylebox_override("pressed", style)
	container.add_child(header)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 8)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	content_margin.add_child(content)
	container.add_child(content_margin)

	header.pressed.connect(func() -> void:
		section_data.collapsed = not section_data.collapsed
		content_margin.visible = not section_data.collapsed
		header.text = ("  %s" if not section_data.collapsed else "  %s") % section_data.display_name
	)

	section_data.container = container
	section_data.header = header
	section_data.content = content

	_main_vbox.add_child(container)


func _get_or_create_button_flow(section_data: Dictionary) -> FlowContainer:
	var content: VBoxContainer = section_data.content
	for child in content.get_children():
		if child is FlowContainer:
			return child
	var flow := FlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(flow)
	return flow


# --- Control Factories ---

func _create_slider_control(full_key: String, config: Dictionary) -> Control:
	var is_int: bool = config.get("type") == "int"
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = config.get("label", full_key.get_slice("/", 1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 50
	value_label.text = _format_number(_values[full_key], is_int)
	hbox.add_child(value_label)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.custom_minimum_size = Vector2(28, 28)
	hbox.add_child(reset_btn)
	vbox.add_child(hbox)

	var slider := HSlider.new()
	slider.min_value = config.get("min", 0.0)
	slider.max_value = config.get("max", 1.0)
	slider.step = config.get("step", 0.01 if not is_int else 1)
	slider.value = _values[full_key]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(slider)

	slider.value_changed.connect(func(val: float) -> void:
		var final_val: Variant = int(val) if is_int else val
		_set_value(full_key, final_val)
		value_label.text = _format_number(final_val, is_int)
	)

	reset_btn.pressed.connect(func() -> void:
		var def: Variant = _defaults[full_key]
		slider.value = def
		var final_val: Variant = int(def) if is_int else def
		_set_value(full_key, final_val)
		value_label.text = _format_number(final_val, is_int)
	)

	return vbox


func _create_checkbox_control(full_key: String, config: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = config.get("label", full_key.get_slice("/", 1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var checkbox := CheckBox.new()
	checkbox.button_pressed = _values[full_key]
	hbox.add_child(checkbox)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.custom_minimum_size = Vector2(28, 28)
	hbox.add_child(reset_btn)

	checkbox.toggled.connect(func(val: bool) -> void:
		_set_value(full_key, val)
	)

	reset_btn.pressed.connect(func() -> void:
		var def: bool = _defaults[full_key]
		checkbox.button_pressed = def
		_set_value(full_key, def)
	)

	return hbox


func _create_color_control(full_key: String, config: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = config.get("label", full_key.get_slice("/", 1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var picker := ColorPickerButton.new()
	picker.color = _values[full_key]
	picker.custom_minimum_size = Vector2(40, 28)
	hbox.add_child(picker)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.custom_minimum_size = Vector2(28, 28)
	hbox.add_child(reset_btn)

	picker.color_changed.connect(func(val: Color) -> void:
		_set_value(full_key, val)
	)

	reset_btn.pressed.connect(func() -> void:
		var def: Color = _defaults[full_key]
		picker.color = def
		_set_value(full_key, def)
	)

	return hbox


func _create_dropdown_control(full_key: String, config: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = config.get("label", full_key.get_slice("/", 1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var option_btn := OptionButton.new()
	var options: Array = config.get("options", [])
	for opt in options:
		option_btn.add_item(opt)
	var default_index: int = config.get("default_index", 0)
	option_btn.selected = default_index
	option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(option_btn)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.custom_minimum_size = Vector2(28, 28)
	hbox.add_child(reset_btn)

	option_btn.item_selected.connect(func(idx: int) -> void:
		var val: String = option_btn.get_item_text(idx)
		_set_value(full_key, val)
	)

	reset_btn.pressed.connect(func() -> void:
		option_btn.selected = default_index
		var val: String = option_btn.get_item_text(default_index)
		_set_value(full_key, val)
	)

	return hbox


func _create_vector2_control(full_key: String, config: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = config.get("label", full_key.get_slice("/", 1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.custom_minimum_size = Vector2(28, 28)
	header.add_child(reset_btn)
	vbox.add_child(header)

	var current: Vector2 = _values[full_key]
	var min_val: Vector2 = config.get("min", Vector2.ZERO)
	var max_val: Vector2 = config.get("max", Vector2(100, 100))
	var step: float = config.get("step", 1.0)

	var sliders: Array[HSlider] = []
	var value_labels: Array[Label] = []
	var axes := ["x", "y"]

	for i in 2:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var axis_label := Label.new()
		axis_label.text = "  %s:" % axes[i]
		axis_label.custom_minimum_size.x = 30
		row.add_child(axis_label)

		var slider := HSlider.new()
		slider.min_value = min_val[axes[i]]
		slider.max_value = max_val[axes[i]]
		slider.step = step
		slider.value = current[axes[i]]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		sliders.append(slider)

		var val_label := Label.new()
		val_label.text = _format_number(current[axes[i]], false)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_label.custom_minimum_size.x = 50
		row.add_child(val_label)
		value_labels.append(val_label)

		vbox.add_child(row)

	var update_fn := func(_val: float) -> void:
		var vec := Vector2(sliders[0].value, sliders[1].value)
		_set_value(full_key, vec)
		for j in 2:
			value_labels[j].text = _format_number(vec[axes[j]], false)

	for slider in sliders:
		slider.value_changed.connect(update_fn)

	reset_btn.pressed.connect(func() -> void:
		var def: Vector2 = _defaults[full_key]
		sliders[0].value = def.x
		sliders[1].value = def.y
		_set_value(full_key, def)
		value_labels[0].text = _format_number(def.x, false)
		value_labels[1].text = _format_number(def.y, false)
	)

	return vbox


func _create_vector3_control(full_key: String, config: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = config.get("label", full_key.get_slice("/", 1))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.custom_minimum_size = Vector2(28, 28)
	header.add_child(reset_btn)
	vbox.add_child(header)

	var current: Vector3 = _values[full_key]
	var min_val: Vector3 = config.get("min", Vector3.ZERO)
	var max_val: Vector3 = config.get("max", Vector3(100, 100, 100))
	var step: float = config.get("step", 1.0)

	var sliders: Array[HSlider] = []
	var value_labels: Array[Label] = []
	var axes := ["x", "y", "z"]

	for i in 3:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var axis_label := Label.new()
		axis_label.text = "  %s:" % axes[i]
		axis_label.custom_minimum_size.x = 30
		row.add_child(axis_label)

		var slider := HSlider.new()
		slider.min_value = min_val[axes[i]]
		slider.max_value = max_val[axes[i]]
		slider.step = step
		slider.value = current[axes[i]]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		sliders.append(slider)

		var val_label := Label.new()
		val_label.text = _format_number(current[axes[i]], false)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_label.custom_minimum_size.x = 50
		row.add_child(val_label)
		value_labels.append(val_label)

		vbox.add_child(row)

	var update_fn := func(_val: float) -> void:
		var vec := Vector3(sliders[0].value, sliders[1].value, sliders[2].value)
		_set_value(full_key, vec)
		for j in 3:
			value_labels[j].text = _format_number(vec[axes[j]], false)

	for slider in sliders:
		slider.value_changed.connect(update_fn)

	reset_btn.pressed.connect(func() -> void:
		var def: Vector3 = _defaults[full_key]
		sliders[0].value = def.x
		sliders[1].value = def.y
		sliders[2].value = def.z
		_set_value(full_key, def)
		value_labels[0].text = _format_number(def.x, false)
		value_labels[1].text = _format_number(def.y, false)
		value_labels[2].text = _format_number(def.z, false)
	)

	return vbox


func _create_button_control(full_key: String, config: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = config.get("label", full_key.get_slice("/", 1))
	btn.pressed.connect(func() -> void:
		print("[gdtuner:action] %s pressed" % full_key)
		button_pressed.emit(full_key)
	)
	return btn


# --- Internal ---

func _set_value(key: String, value: Variant) -> void:
	_values[key] = value
	print("[gdtuner] %s = %s" % [key, _format_value(value)])
	value_changed.emit(key, value)


func _format_value(val: Variant) -> String:
	if val is String:
		return '"%s"' % val
	if val is Color:
		return "Color(%s, %s, %s, %s)" % [val.r, val.g, val.b, val.a]
	if val is Vector2:
		return "Vector2(%s, %s)" % [val.x, val.y]
	if val is Vector3:
		return "Vector3(%s, %s, %s)" % [val.x, val.y, val.z]
	return str(val)


func _format_number(val: Variant, is_int: bool) -> String:
	if is_int:
		return str(int(val))
	return "%.2f" % val


# --- Bake to Source ---

func bake_all_values() -> void:
	if not _is_debug:
		return
	# Group controls by script path
	var script_controls: Dictionary = {}
	for section_id in _sections:
		var script_path: String = _section_scripts.get(section_id, "")
		if script_path.is_empty():
			continue
		var section_data: Dictionary = _sections[section_id]
		for full_key in section_data.controls:
			if not _control_configs.has(full_key):
				continue
			var config: Dictionary = _control_configs[full_key]
			if config.get("type", "") == "button":
				continue
			if not script_controls.has(script_path):
				script_controls[script_path] = []
			script_controls[script_path].append({
				"full_key": full_key,
				"config": config,
			})

	var files_modified := 0
	for script_path in script_controls:
		var file := FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			print("[gdtuner] ERROR: Cannot read %s" % script_path)
			continue
		var source: String = file.get_as_text()
		file.close()

		var modified := false
		for entry in script_controls[script_path]:
			var full_key: String = entry.full_key
			var config: Dictionary = entry.config
			var key: String = full_key.get_slice("/", 1)
			var current_value: Variant = _values.get(full_key)
			var new_source := _bake_control_value(source, config, key, current_value)
			if new_source != source:
				source = new_source
				modified = true

		if modified:
			file = FileAccess.open(script_path, FileAccess.WRITE)
			if file:
				file.store_string(source)
				file.close()
				files_modified += 1
				print("[gdtuner] Baked values to %s" % script_path)

	print("[gdtuner] Bake complete — %d file(s) modified" % files_modified)


func _bake_control_value(source: String, config: Dictionary, key: String, value: Variant) -> String:
	var control_type: String = config.get("type", "")
	var method_name: String
	var default_arg_index: int  # 0-based, counting from after opening paren
	match control_type:
		"float":
			method_name = "add_float"
			default_arg_index = 3
		"int":
			method_name = "add_int"
			default_arg_index = 3
		"bool":
			method_name = "add_bool"
			default_arg_index = 1
		"color":
			method_name = "add_color"
			default_arg_index = 1
		"dropdown":
			method_name = "add_dropdown"
			default_arg_index = 2
		"vector2":
			method_name = "add_vector2"
			default_arg_index = 1
		"vector3":
			method_name = "add_vector3"
			default_arg_index = 1
		_:
			return source

	# Find the method call for this key
	var regex := RegEx.new()
	regex.compile(method_name + '\\s*\\(\\s*"' + key + '"')
	var result := regex.search(source)
	if result == null:
		return source

	# Find the opening paren and its matching close
	var paren_start := source.find("(", result.get_start())
	var paren_end := _find_matching_paren(source, paren_start)
	if paren_end < 0:
		return source

	var args_str := source.substr(paren_start + 1, paren_end - paren_start - 1)
	var args := _split_args(args_str)
	if default_arg_index >= args.size():
		return source

	# Format the new value
	var new_value_str: String
	match control_type:
		"float":
			new_value_str = str(value)
		"int":
			new_value_str = str(int(value))
		"bool":
			new_value_str = "true" if value else "false"
		"color":
			new_value_str = "Color(%s, %s, %s, %s)" % [value.r, value.g, value.b, value.a]
		"vector2":
			new_value_str = "Vector2(%s, %s)" % [value.x, value.y]
		"vector3":
			new_value_str = "Vector3(%s, %s, %s)" % [value.x, value.y, value.z]
		"dropdown":
			var options: Array = config.get("options", [])
			var idx := options.find(value)
			if idx < 0:
				idx = 0
			new_value_str = str(idx)

	# Preserve surrounding whitespace in the argument
	var old_arg: String = args[default_arg_index]
	var trimmed := old_arg.strip_edges()
	var prefix := old_arg.substr(0, old_arg.find(trimmed))
	var suffix := old_arg.substr(old_arg.find(trimmed) + trimmed.length())
	args[default_arg_index] = prefix + new_value_str + suffix

	var new_args_str := ",".join(args)
	return source.substr(0, paren_start + 1) + new_args_str + source.substr(paren_end)


func _find_matching_paren(source: String, open_pos: int) -> int:
	var depth := 0
	for i in range(open_pos, source.length()):
		var ch: String = source[i]
		if ch == "(" or ch == "[":
			depth += 1
		elif ch == ")" or ch == "]":
			depth -= 1
			if depth == 0:
				return i
	return -1


func _split_args(args_str: String) -> Array[String]:
	var args: Array[String] = []
	var depth := 0
	var in_string := false
	var current := ""
	var prev_ch := ""
	for i in range(args_str.length()):
		var ch: String = args_str[i]
		if ch == '"' and prev_ch != "\\":
			in_string = not in_string
			current += ch
		elif in_string:
			current += ch
		elif ch == "(" or ch == "[":
			depth += 1
			current += ch
		elif ch == ")" or ch == "]":
			depth -= 1
			current += ch
		elif ch == "," and depth == 0:
			args.append(current)
			current = ""
		else:
			current += ch
		prev_ch = ch
	if not current.is_empty():
		args.append(current)
	return args
