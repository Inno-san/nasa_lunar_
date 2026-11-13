extends Control
## Top HUD and bottom status/touch bar.
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
var day5_test_button: Button
var reset_button: Button

var dpad_state := {"up": false, "down": false, "left": false, "right": false}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameState.state_changed.connect(_on_game_state_changed)
	_on_game_state_changed()


func _build_ui() -> void:
	# --- TOP BAR ---
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 86.0
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.07, 0.1, 0.16, 0.94)
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.28, 0.48, 0.72, 1.0)
	top_style.content_margin_left = 14
	top_style.content_margin_right = 14
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(top_bar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	top_bar.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 14)
	vbox.add_child(row1)

	day_label = _make_stat_chip(row1, "Day", "Current mission day out of 10. Survive all 10 days!", Color(0.95, 0.85, 0.35))
	ap_label = _make_stat_chip(row1, "AP", "Action Points (AP) left today. Walking is free; console tasks use AP.", Color(0.45, 0.88, 1.0))
	battery_label = _make_stat_chip(row1, "Battery", "Stored Power Units (PU). Solar panels add power each day.", Color(1.0, 0.8, 0.25))
	oxygen_label = _make_stat_chip(row1, "Oxygen", "Breathable air for the crew. Made by Life Support.", Color(0.45, 0.92, 0.95))
	food_label = _make_stat_chip(row1, "Food", "Meals for the crew. Grown in the Greenhouse (takes 2 days to harvest).", Color(0.55, 0.92, 0.48))
	water_label = _make_stat_chip(row1, "Water", "Clean water for plants and crew. Recycled daily (+2/day).", Color(0.4, 0.7, 1.0))
	health_label = _make_stat_chip(row1, "Health", "Crew well-being! Keep above 50 by Day 10 to win.", Color(1.0, 0.48, 0.52))
	shield_label = _make_stat_chip(row1, "Shield", "Radiation protection level (0-3). Reduces storm damage.", Color(0.78, 0.62, 1.0))
	science_label = _make_stat_chip(row1, "Science", "Science points earned from experiments (30+ needed for 3 stars).", Color(0.95, 0.7, 0.95))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)

	end_day_button = Button.new()
	end_day_button.text = "End Day >>"
	end_day_button.tooltip_text = "Finish today and run the daily power, oxygen, food, water, and health checks."
	end_day_button.custom_minimum_size = Vector2(120, 34)
	end_day_button.pressed.connect(_on_end_day_pressed)
	row1.add_child(end_day_button)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	vbox.add_child(row2)

	modes_label = Label.new()
	modes_label.add_theme_font_size_override("font_size", 13)
	modes_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	row2.add_child(modes_label)

	var disclaimer := Label.new()
	disclaimer.text = "Note: Game values are simplified for training — not real engineering specs or live NASA measurements."
	disclaimer.add_theme_font_size_override("font_size", 12)
	disclaimer.add_theme_color_override("font_color", Color(0.68, 0.75, 0.84))
	disclaimer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(disclaimer)

	day5_test_button = Button.new()
	day5_test_button.text = "Run Day-5 Test"
	day5_test_button.tooltip_text = "Reproduce the Day-5 worked example from docs/game_mechanics.md and verify all meters."
	day5_test_button.pressed.connect(_on_day5_test_pressed)
	row2.add_child(day5_test_button)

	reset_button = Button.new()
	reset_button.text = "Reset Day 1"
	reset_button.tooltip_text = "Restart the mission from Day 1."
	reset_button.pressed.connect(_on_reset_pressed)
	row2.add_child(reset_button)

	# --- BOTTOM LOG PANEL ---
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.18
	bottom_panel.anchor_right = 0.84
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -94.0
	bottom_panel.offset_bottom = -10.0
	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.09, 0.14, 0.9)
	bot_style.border_width_top = 2
	bot_style.border_width_left = 2
	bot_style.border_width_right = 2
	bot_style.border_width_bottom = 2
	bot_style.border_color = Color(0.25, 0.42, 0.62, 0.9)
	bot_style.corner_radius_top_left = 6
	bot_style.corner_radius_top_right = 6
	bot_style.corner_radius_bottom_left = 6
	bot_style.corner_radius_bottom_right = 6
	bot_style.content_margin_left = 12
	bot_style.content_margin_right = 12
	bot_style.content_margin_top = 6
	bot_style.content_margin_bottom = 6
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	add_child(bottom_panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 13)
	bottom_panel.add_child(log_label)

	# --- ON-SCREEN TOUCH / CURSOR CONTROLS ---
	_build_touch_controls()


func _make_stat_chip(parent: Container, title: String, tip: String, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.tooltip_text = tip
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.17, 0.25, 1.0)
	st.border_width_bottom = 2
	st.border_color = color
	st.corner_radius_top_left = 4
	st.corner_radius_top_right = 4
	st.corner_radius_bottom_left = 4
	st.corner_radius_bottom_right = 4
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", st)
	parent.add_child(panel)

	var lbl := Label.new()
	lbl.text = title
	lbl.tooltip_text = tip
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	panel.add_child(lbl)
	return lbl


func _build_touch_controls() -> void:
	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.anchor_left = 0.0
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = 16.0
	dpad.offset_top = -142.0
	dpad.offset_right = 166.0
	dpad.offset_bottom = -12.0
	dpad.add_theme_constant_override("h_separation", 4)
	dpad.add_theme_constant_override("v_separation", 4)
	add_child(dpad)

	dpad.add_child(Control.new())
	_add_dpad_btn(dpad, "^", "up")
	dpad.add_child(Control.new())
	_add_dpad_btn(dpad, "<", "left")
	_add_dpad_btn(dpad, "v", "down")
	_add_dpad_btn(dpad, ">", "right")

	var use_btn := Button.new()
	use_btn.text = "Use Facility\n[E]"
	use_btn.anchor_left = 1.0
	use_btn.anchor_right = 1.0
	use_btn.anchor_top = 1.0
	use_btn.anchor_bottom = 1.0
	use_btn.offset_left = -168.0
	use_btn.offset_right = -18.0
	use_btn.offset_top = -88.0
	use_btn.offset_bottom = -16.0
	use_btn.pressed.connect(func() -> void: interact_pressed.emit())
	add_child(use_btn)


func _add_dpad_btn(parent: Container, text_str: String, dir_key: String) -> void:
	var btn := Button.new()
	btn.text = text_str
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


func _on_game_state_changed() -> void:
	day_label.text = "Day %d/%d" % [GameState.day, Rules.mission_days()]
	ap_label.text = "AP %d/%d" % [GameState.ap, Rules.ap_per_day()]
	battery_label.text = "Battery %d/%d" % [GameState.battery, Rules.max_value("battery")]
	oxygen_label.text = "Oxygen %d/%d" % [GameState.oxygen, Rules.max_value("oxygen")]
	food_label.text = "Food %d/%d" % [GameState.food, Rules.max_value("food")]
	water_label.text = "Water %d/%d" % [GameState.water, Rules.max_value("water")]
	health_label.text = "Health %d/%d" % [GameState.health, Rules.max_value("health")]
	shield_label.text = "Shield %d/%d" % [GameState.shield, Rules.max_value("shield")]
	science_label.text = "Science %d" % GameState.science

	modes_label.text = "Life Support: %s  |  Greenhouse: %s" % [
		GameState.life_support_mode.capitalize(),
		GameState.greenhouse_mode.capitalize()
	]

	end_day_button.disabled = GameState.game_over

	var recent_lines: Array[String] = []
	var start_idx := maxi(0, GameState.daily_log.size() - 6)
	for i in range(start_idx, GameState.daily_log.size()):
		recent_lines.append("• " + GameState.daily_log[i])
	log_label.text = "\n".join(recent_lines)


func _on_end_day_pressed() -> void:
	GameState.end_day()


func _on_day5_test_pressed() -> void:
	GameState.run_day5_debug_test()


func _on_reset_pressed() -> void:
	GameState.reset_game()

