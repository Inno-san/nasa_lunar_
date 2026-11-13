extends Control
## Top HUD, glossary bar, audio mute toggle, and bottom status/touch bar.
## Listens to GameState.state_changed and never caches game values locally.

signal touch_move_changed(direction: Vector2)
signal interact_pressed

var top_bar: PanelContainer
var day_label: Label
var ap_label: Label
var battery_label: Label
var oxygen_label: Label
var food_label: Label
var water_label: Label
var health_label: Label
var shield_label: Label
var science_label: Label
var modes_label: Label
var log_label: RichTextLabel
var end_day_button: Button
var mute_button: Button
var day5_test_button: Button
var reset_button: Button

var dpad_state := {"up": false, "down": false, "left": false, "right": false}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameState.state_changed.connect(_on_game_state_changed)
	AudioManager.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(AudioManager.muted)
	_on_game_state_changed()


func _build_ui() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 104.0
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.09, 0.15, 0.96)
	top_style.border_width_bottom = 3
	top_style.border_color = Color(0.32, 0.56, 0.85, 1.0)
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(top_bar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	top_bar.add_child(vbox)

	# Row 1: Meters + End Day
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)

	day_label = _make_stat_chip(row1, "Day", "Current mission day out of 10. Survive all 10 days!", Color(0.98, 0.88, 0.4), "")
	ap_label = _make_stat_chip(row1, "AP", "Action Points (AP) left today. Walking is free; console tasks use AP.", Color(0.55, 0.9, 1.0), "")
	battery_label = _make_stat_chip(row1, "Battery", Explain.term_text("battery"), Color(1.0, 0.82, 0.3), "battery")
	oxygen_label = _make_stat_chip(row1, "Oxygen", Explain.term_text("oxygen"), Color(0.5, 0.95, 0.98), "oxygen")
	food_label = _make_stat_chip(row1, "Food", Explain.term_text("greenhouse"), Color(0.6, 0.95, 0.55), "greenhouse")
	water_label = _make_stat_chip(row1, "Water", "Clean water for plants and crew. Recycled daily (+2/day).", Color(0.5, 0.78, 1.0), "")
	health_label = _make_stat_chip(row1, "Health", "Crew well-being! Keep at 50 or above by Day 10 to win.", Color(1.0, 0.58, 0.6), "")
	shield_label = _make_stat_chip(row1, "Shield", Explain.term_text("shielding"), Color(0.82, 0.68, 1.0), "shielding")
	science_label = _make_stat_chip(row1, "Science", "Science points earned from experiments (30+ needed for 3 stars).", Color(0.96, 0.74, 0.96), "")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)

	end_day_button = Button.new()
	end_day_button.text = "End Day >>"
	end_day_button.tooltip_text = "Finish today and run the daily power, oxygen, food, water, and health checks."
	end_day_button.custom_minimum_size = Vector2(130, 38)
	end_day_button.add_theme_font_size_override("font_size", 16)
	end_day_button.pressed.connect(_on_end_day_pressed)
	row1.add_child(end_day_button)

	# Row 2: Active modes, Tap-to-Explain term buttons, Sound toggle, Debug test
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	vbox.add_child(row2)

	modes_label = Label.new()
	modes_label.add_theme_font_size_override("font_size", 14)
	modes_label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	row2.add_child(modes_label)

	var explain_lbl := Label.new()
	explain_lbl.text = "  |  Tap to explain:"
	explain_lbl.add_theme_font_size_override("font_size", 13)
	explain_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	row2.add_child(explain_lbl)

	for term_pair in [
		["solar_storm", "Solar Storm?"],
		["radiation", "Radiation?"],
		["shielding", "Shielding?"],
		["comm_delay", "Comms Delay?"],
	]:
		var tbtn := Button.new()
		tbtn.text = term_pair[1]
		tbtn.tooltip_text = Explain.term_text(term_pair[0])
		tbtn.add_theme_font_size_override("font_size", 13)
		tbtn.pressed.connect(Explain.show_term.bind(term_pair[0]))
		row2.add_child(tbtn)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer2)

	mute_button = Button.new()
	mute_button.text = "Sound: ON"
	mute_button.tooltip_text = "Toggle game sound effects on or off."
	mute_button.add_theme_font_size_override("font_size", 13)
	mute_button.pressed.connect(func() -> void: AudioManager.toggle_mute())
	row2.add_child(mute_button)

	day5_test_button = Button.new()
	day5_test_button.text = "Day-5 Test"
	day5_test_button.tooltip_text = "Reproduce the Day-5 worked example from docs/game_mechanics.md."
	day5_test_button.add_theme_font_size_override("font_size", 13)
	day5_test_button.pressed.connect(_on_day5_test_pressed)
	row2.add_child(day5_test_button)

	reset_button = Button.new()
	reset_button.text = "Menu"
	reset_button.tooltip_text = "Return to the Start Menu."
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.pressed.connect(_on_menu_pressed)
	row2.add_child(reset_button)

	# Bottom log panel
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.16
	bottom_panel.anchor_right = 0.84
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -92.0
	bottom_panel.offset_bottom = -8.0
	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.09, 0.14, 0.92)
	bot_style.set_border_width_all(2)
	bot_style.border_color = Color(0.28, 0.48, 0.72, 0.95)
	bot_style.set_corner_radius_all(6)
	bot_style.content_margin_left = 12
	bot_style.content_margin_right = 12
	bot_style.content_margin_top = 6
	bot_style.content_margin_bottom = 6
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	add_child(bottom_panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 14)
	bottom_panel.add_child(log_label)

	_build_touch_controls()


func _make_stat_chip(parent: Container, title: String, tip: String, color: Color, term_id: String) -> Label:
	var btn := Button.new()
	btn.tooltip_text = tip + (" (Click to explain)" if term_id != "" else "")
	btn.flat = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.17, 0.25, 1.0)
	st.border_width_bottom = 3
	st.border_color = color
	st.set_corner_radius_all(4)
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	if term_id != "":
		btn.pressed.connect(Explain.show_term.bind(term_id))
	parent.add_child(btn)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	btn.custom_minimum_size = Vector2(96, 34)
	btn.text = title
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", color)
	# Return a proxy label or use the button itself by keeping a child hidden label synced:
	lbl.visible = false
	btn.add_child(lbl)
	lbl.set_meta("chip_btn", btn)
	return lbl


func _set_chip_text(lbl: Label, text_val: String) -> void:
	lbl.text = text_val
	var btn: Button = lbl.get_meta("chip_btn", null)
	if btn != null:
		btn.text = text_val


func _status_tag(val: int, max_val: int) -> String:
	if val <= 0:
		return " [!]"
	if val <= int(max_val * 0.25):
		return " [LOW]"
	return ""


func _build_touch_controls() -> void:
	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.anchor_left = 0.0
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = 14.0
	dpad.offset_top = -140.0
	dpad.offset_right = 164.0
	dpad.offset_bottom = -10.0
	dpad.add_theme_constant_override("h_separation", 4)
	dpad.add_theme_constant_override("v_separation", 4)
	add_child(dpad)

	dpad.add_child(Control.new())
	_add_dpad_btn(dpad, "▲", "up")
	dpad.add_child(Control.new())
	_add_dpad_btn(dpad, "◀", "left")
	_add_dpad_btn(dpad, "▼", "down")
	_add_dpad_btn(dpad, "▶", "right")

	var use_btn := Button.new()
	use_btn.text = "Use Room\n[E]"
	use_btn.add_theme_font_size_override("font_size", 15)
	use_btn.anchor_left = 1.0
	use_btn.anchor_right = 1.0
	use_btn.anchor_top = 1.0
	use_btn.anchor_bottom = 1.0
	use_btn.offset_left = -168.0
	use_btn.offset_right = -16.0
	use_btn.offset_top = -88.0
	use_btn.offset_bottom = -12.0
	use_btn.pressed.connect(func() -> void: interact_pressed.emit())
	add_child(use_btn)


func _add_dpad_btn(parent: Container, text_str: String, dir_key: String) -> void:
	var btn := Button.new()
	btn.text = text_str
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(44, 38)
	btn.button_down.connect(func() -> void:
		dpad_state[dir_key] = true
		_emit_dpad()
	)
	btn.button_up.connect(func() -> void:
		dpad_state[dir_key] = false
		_emit_dpad()
	)
	parent.add_child(btn)


func _emit_dpad() -> void:
	var vec := Vector2.ZERO
	if dpad_state["left"]:
		vec.x -= 1.0
	if dpad_state["right"]:
		vec.x += 1.0
	if dpad_state["up"]:
		vec.y -= 1.0
	if dpad_state["down"]:
		vec.y += 1.0
	touch_move_changed.emit(vec.normalized())


func _on_mute_changed(is_muted: bool) -> void:
	if mute_button != null:
		mute_button.text = "Sound: MUTED" if is_muted else "Sound: ON"


func _on_game_state_changed() -> void:
	var b_max := GameState.battery_max()
	var o_max := Rules.max_value("oxygen")
	var f_max := Rules.max_value("food")
	var w_max := Rules.max_value("water")
	var h_max := Rules.max_value("health")

	_set_chip_text(day_label, "Day %d/%d" % [GameState.day, Rules.mission_days()])
	_set_chip_text(ap_label, "AP %d/%d" % [GameState.ap, Rules.ap_per_day()])
	_set_chip_text(battery_label, "Bat %d/%d%s?" % [GameState.battery, b_max, _status_tag(GameState.battery, b_max)])
	_set_chip_text(oxygen_label, "O2 %d/%d%s?" % [GameState.oxygen, o_max, _status_tag(GameState.oxygen, o_max)])
	_set_chip_text(food_label, "Food %d/%d%s?" % [GameState.food, f_max, _status_tag(GameState.food, f_max)])
	_set_chip_text(water_label, "Water %d/%d%s" % [GameState.water, w_max, _status_tag(GameState.water, w_max)])
	_set_chip_text(health_label, "HP %d/%d%s" % [GameState.health, h_max, _status_tag(GameState.health, h_max)])
	_set_chip_text(shield_label, "Shield %d/%d?" % [GameState.shield, Rules.max_value("shield")])
	_set_chip_text(science_label, "Sci %d" % GameState.science)

	modes_label.text = "LS: %s | GH: %s (Simplified game values)" % [
		GameState.life_support_mode.capitalize(),
		GameState.greenhouse_mode.capitalize(),
	]

	end_day_button.disabled = GameState.game_over or GameState.phase != GameState.PHASE_PLAYING

	var recent_lines: Array[String] = []
	var start_idx := maxi(0, GameState.daily_log.size() - 5)
	for i in range(start_idx, GameState.daily_log.size()):
		recent_lines.append("• " + GameState.daily_log[i])
	log_label.text = "\n".join(recent_lines)


func _on_end_day_pressed() -> void:
	GameState.end_day()


func _on_day5_test_pressed() -> void:
	GameState.run_day5_debug_test()


func _on_menu_pressed() -> void:
	AudioManager.stop_alarm()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
