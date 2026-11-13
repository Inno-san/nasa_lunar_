extends Control
## Visual, zero-math Top HUD with progress bars, trend arrows, Action dots, and a live Coach Tip bar.
## Listens to GameState.state_changed and never caches game values locally.

signal touch_move_changed(direction: Vector2)
signal interact_pressed

var top_bar: PanelContainer
var day_label: Label
var ap_label: Label
var shield_label: Label
var science_label: Label
var coach_label: Label
var log_label: RichTextLabel
var end_day_button: Button
var mute_button: Button
var day5_test_button: Button
var reset_button: Button

var meter_widgets: Dictionary = {}
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
	top_bar.offset_bottom = 114.0
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.09, 0.15, 0.96)
	top_style.border_width_bottom = 3
	top_style.border_color = Color(0.32, 0.56, 0.85, 1.0)
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 6
	top_style.content_margin_bottom = 6
	top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(top_bar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	top_bar.add_child(vbox)

	# Row 1: Visual Meter Bars + Next Day Button
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)

	day_label = _make_badge(row1, "Day 1", Color(0.98, 0.88, 0.4), "")
	ap_label = _make_badge(row1, "Actions: ●●●●●●", Color(0.55, 0.9, 1.0), "")

	meter_widgets["battery"] = _make_bar_meter(row1, "Battery", Color(1.0, 0.82, 0.28), "battery")
	meter_widgets["oxygen"] = _make_bar_meter(row1, "Oxygen", Color(0.45, 0.92, 0.98), "oxygen")
	meter_widgets["food"] = _make_bar_meter(row1, "Food", Color(0.55, 0.92, 0.52), "greenhouse")
	meter_widgets["water"] = _make_bar_meter(row1, "Water", Color(0.48, 0.76, 1.0), "")
	meter_widgets["health"] = _make_bar_meter(row1, "Health", Color(1.0, 0.56, 0.6), "")

	shield_label = _make_badge(row1, "Shield: ★☆☆", Color(0.84, 0.7, 1.0), "shielding")
	science_label = _make_badge(row1, "Science: ☆☆☆", Color(0.96, 0.74, 0.96), "")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)

	end_day_button = Button.new()
	end_day_button.text = "Next Day >>"
	end_day_button.tooltip_text = "Finish today and sleep until tomorrow."
	end_day_button.custom_minimum_size = Vector2(138, 48)
	end_day_button.add_theme_font_size_override("font_size", 17)
	end_day_button.pressed.connect(_on_end_day_pressed)
	row1.add_child(end_day_button)

	# Row 2: Live Coach Hint (no math!) + Word Explainer + Sound toggle
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	vbox.add_child(row2)

	coach_label = Label.new()
	coach_label.add_theme_font_size_override("font_size", 15)
	coach_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.58))
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(coach_label)

	for term_pair in [
		["solar_storm", "Solar Storm?"],
		["radiation", "Radiation?"],
		["comm_delay", "Earth Delay?"],
	]:
		var tbtn := Button.new()
		tbtn.text = term_pair[1]
		tbtn.add_theme_font_size_override("font_size", 13)
		tbtn.pressed.connect(Explain.show_term.bind(term_pair[0]))
		row2.add_child(tbtn)

	mute_button = Button.new()
	mute_button.text = "Sound: ON"
	mute_button.add_theme_font_size_override("font_size", 13)
	mute_button.pressed.connect(func() -> void: AudioManager.toggle_mute())
	row2.add_child(mute_button)

	day5_test_button = Button.new()
	day5_test_button.text = "Day-5 Test"
	day5_test_button.tooltip_text = "Verify the Day-5 test from docs/game_mechanics.md."
	day5_test_button.add_theme_font_size_override("font_size", 12)
	day5_test_button.pressed.connect(_on_day5_test_pressed)
	row2.add_child(day5_test_button)

	reset_button = Button.new()
	reset_button.text = "Menu"
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.pressed.connect(_on_menu_pressed)
	row2.add_child(reset_button)

	# Bottom plain-language story log
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.16
	bottom_panel.anchor_right = 0.84
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -78.0
	bottom_panel.offset_bottom = -8.0
	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.09, 0.14, 0.9)
	bot_style.set_border_width_all(2)
	bot_style.border_color = Color(0.28, 0.48, 0.72, 0.95)
	bot_style.set_corner_radius_all(6)
	bot_style.content_margin_left = 12
	bot_style.content_margin_right = 12
	bot_style.content_margin_top = 5
	bot_style.content_margin_bottom = 5
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	add_child(bottom_panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 14)
	bottom_panel.add_child(log_label)

	_build_touch_controls()


func _make_badge(parent: Container, text_str: String, color: Color, term_id: String) -> Label:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.17, 0.25, 1.0)
	st.border_width_bottom = 3
	st.border_color = color
	st.set_corner_radius_all(5)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", st)
	if term_id != "":
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				Explain.show_term(term_id)
		)
	parent.add_child(panel)

	var lbl := Label.new()
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	panel.add_child(lbl)
	return lbl


func _make_bar_meter(parent: Container, title: String, color: Color, term_id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(128, 48)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.16, 0.24, 1.0)
	st.border_width_bottom = 3
	st.border_color = color
	st.set_corner_radius_all(5)
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", st)
	if term_id != "":
		panel.tooltip_text = "Click to learn about " + title
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				Explain.show_term(term_id)
		)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top_lbl := Label.new()
	top_lbl.text = title
	top_lbl.add_theme_font_size_override("font_size", 13)
	top_lbl.add_theme_color_override("font_color", color)
	box.add_child(top_lbl)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)

	var trend_lbl := Label.new()
	trend_lbl.add_theme_font_size_override("font_size", 12)
	trend_lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
	box.add_child(trend_lbl)

	return {"title": title, "top": top_lbl, "bar": bar, "trend": trend_lbl, "fill": fill, "base_color": color}


func _build_touch_controls() -> void:
	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.anchor_left = 0.0
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = 14.0
	dpad.offset_top = -136.0
	dpad.offset_right = 164.0
	dpad.offset_bottom = -8.0
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
	use_btn.text = "Open Room\n[E]"
	use_btn.add_theme_font_size_override("font_size", 15)
	use_btn.anchor_left = 1.0
	use_btn.anchor_right = 1.0
	use_btn.anchor_top = 1.0
	use_btn.anchor_bottom = 1.0
	use_btn.offset_left = -168.0
	use_btn.offset_right = -16.0
	use_btn.offset_top = -84.0
	use_btn.offset_bottom = -10.0
	use_btn.pressed.connect(func() -> void: interact_pressed.emit())
	add_child(use_btn)


func _add_dpad_btn(parent: Container, text_str: String, dir_key: String) -> void:
	var btn := Button.new()
	btn.text = text_str
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(44, 36)
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
	day_label.text = "Day %d of %d" % [GameState.day, Rules.mission_days()]
	ap_label.text = "Actions:\n" + GameState.ap_dots()

	for key in meter_widgets:
		var w: Dictionary = meter_widgets[key]
		var val := int(GameState.get(key))
		var max_v := GameState.battery_max() if key == "battery" else Rules.max_value(key)
		var bar: ProgressBar = w["bar"]
		bar.max_value = max_v
		bar.value = val
		var word := GameState.meter_word(key)
		w["top"].text = "%s: %s" % [w["title"], word]
		w["trend"].text = GameState.meter_trend(key)
		var fill: StyleBoxFlat = w["fill"]
		if word in ["LOW!", "EMPTY!"]:
			fill.bg_color = Color(1.0, 0.42, 0.42)
		else:
			fill.bg_color = w["base_color"]

	var sh_stars := ""
	for i in range(Rules.max_value("shield")):
		sh_stars += "★" if i < GameState.shield else "☆"
	shield_label.text = "Shield\n" + sh_stars

	var sci_goal := maxi(1, int(Rules.win_data().get("three_stars_science", 30)))
	var sci_bars := clampi(int(round(float(GameState.science) / float(sci_goal) * 3.0)), 0, 3)
	var sci_stars := ""
	for i in range(3):
		sci_stars += "★" if i < sci_bars else "☆"
	science_label.text = "Science\n" + sci_stars

	coach_label.text = GameState.coach_hint()
	end_day_button.disabled = GameState.game_over or GameState.phase != GameState.PHASE_PLAYING

	var recent_lines: Array[String] = []
	var start_idx := maxi(0, GameState.daily_log.size() - 3)
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
