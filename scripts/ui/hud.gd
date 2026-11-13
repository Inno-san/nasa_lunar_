extends Control
## Sleek cosmic-purple chamfered HUD matching the reference sci-fi dashboard UI.
## Zero mental math: visual progress bars, status words, trend arrows, Action dots,
## and a bottom control dock with golden-yellow action buttons.

signal touch_move_changed(direction: Vector2)
signal interact_pressed

var top_bar: PanelContainer
var bottom_dock: PanelContainer
var day_ap_label: Label
var shield_label: Label
var science_label: Label
var coach_label: Label
var end_day_button: Button
var dashboard_button: Button
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
	# 1. TOP CHAMFERED STATUS BAR (compact, deep cosmic purple + neon violet border)
	top_bar = PanelContainer.new()
	top_bar.anchor_left = 0.03
	top_bar.anchor_right = 0.97
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 6.0
	top_bar.offset_bottom = 86.0
	top_bar.add_theme_stylebox_override(
		"panel",
		UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 8, 12, 6)
	)
	add_child(top_bar)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 4)
	top_bar.add_child(top_vbox)

	var meters_row := HBoxContainer.new()
	meters_row.add_theme_constant_override("separation", 8)
	top_vbox.add_child(meters_row)

	meter_widgets["battery"] = _make_bar_meter(meters_row, "BATTERY", Color(0.98, 0.76, 0.08), "battery")
	meter_widgets["oxygen"] = _make_bar_meter(meters_row, "OXYGEN", Color(0.32, 0.88, 0.98), "oxygen")
	meter_widgets["food"] = _make_bar_meter(meters_row, "FOOD", Color(0.35, 0.92, 0.55), "greenhouse")
	meter_widgets["water"] = _make_bar_meter(meters_row, "WATER", Color(0.45, 0.72, 1.0), "")
	meter_widgets["health"] = _make_bar_meter(meters_row, "HEALTH", Color(1.0, 0.45, 0.58), "")

	shield_label = _make_badge(meters_row, "SHIELD\n★☆☆", Color(0.75, 0.55, 1.0), "shielding")
	science_label = _make_badge(meters_row, "SCIENCE\n☆☆☆", Color(0.98, 0.76, 0.08), "")

	# Coach / Status row inside top bar
	var coach_row := HBoxContainer.new()
	coach_row.add_theme_constant_override("separation", 8)
	top_vbox.add_child(coach_row)

	coach_label = Label.new()
	coach_label.add_theme_font_size_override("font_size", 13)
	coach_label.add_theme_color_override("font_color", UiKit.COLOR_GOLD)
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_row.add_child(coach_label)

	for term_pair in [
		["solar_storm", "? SOLAR STORM"],
		["radiation", "? RADIATION"],
		["comm_delay", "? EARTH DELAY"],
	]:
		var tbtn := UiKit.button(term_pair[1], 11, Vector2(0, 22))
		tbtn.pressed.connect(Explain.show_term.bind(term_pair[0]))
		coach_row.add_child(tbtn)

	# 2. BOTTOM CHAMFERED CONTROL DOCK (matches the reference screenshot's bottom bar)
	bottom_dock = PanelContainer.new()
	bottom_dock.anchor_left = 0.5
	bottom_dock.anchor_right = 0.5
	bottom_dock.anchor_top = 1.0
	bottom_dock.anchor_bottom = 1.0
	bottom_dock.offset_left = -380.0
	bottom_dock.offset_right = 380.0
	bottom_dock.offset_top = -54.0
	bottom_dock.offset_bottom = -6.0
	bottom_dock.add_theme_stylebox_override(
		"panel",
		UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 8, 12, 6)
	)
	add_child(bottom_dock)

	var dock_row := HBoxContainer.new()
	dock_row.add_theme_constant_override("separation", 12)
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_dock.add_child(dock_row)

	# Left golden CTA button (like "RESEARCH" in the reference screenshot)
	dashboard_button = UiKit.gold_button("DASHBOARD [E]", 14, Vector2(148, 34))
	dashboard_button.tooltip_text = "Open or close the Lunar Outpost command dashboard."
	dashboard_button.pressed.connect(func() -> void: interact_pressed.emit())
	dock_row.add_child(dashboard_button)

	# Center status counter (like "19 / 6 / 500" in the reference screenshot)
	day_ap_label = Label.new()
	day_ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_ap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_ap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_ap_label.add_theme_font_size_override("font_size", 15)
	day_ap_label.add_theme_color_override("font_color", UiKit.COLOR_TEXT)
	dock_row.add_child(day_ap_label)

	# Right golden control buttons (like the [■] [▶] [▶▶] [▶▶▶] cluster in the reference screenshot)
	mute_button = UiKit.button("🔊 ON", 12, Vector2(64, 34))
	mute_button.tooltip_text = "Mute or unmute game audio."
	mute_button.pressed.connect(func() -> void: AudioManager.toggle_mute())
	dock_row.add_child(mute_button)

	day5_test_button = UiKit.button("DAY-5", 11, Vector2(58, 34))
	day5_test_button.tooltip_text = "Run Day-5 verification test."
	day5_test_button.pressed.connect(_on_day5_test_pressed)
	dock_row.add_child(day5_test_button)

	reset_button = UiKit.button("MENU", 12, Vector2(62, 34))
	reset_button.tooltip_text = "Return to Main Menu."
	reset_button.pressed.connect(_on_menu_pressed)
	dock_row.add_child(reset_button)

	end_day_button = UiKit.gold_button("▶▶ NEXT DAY", 14, Vector2(132, 34))
	end_day_button.tooltip_text = "Finish today and advance to the next day."
	end_day_button.pressed.connect(_on_end_day_pressed)
	dock_row.add_child(end_day_button)

	_build_touch_controls()


func _make_badge(parent: Container, text_str: String, color: Color, term_id: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 44)
	panel.add_theme_stylebox_override(
		"panel",
		UiKit.panel_style(UiKit.COLOR_ROW, color, 5, 8, 4)
	)
	if term_id != "":
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				Explain.show_term(term_id)
		)
	parent.add_child(panel)

	var lbl := Label.new()
	lbl.text = text_str
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	panel.add_child(lbl)
	return lbl


func _make_bar_meter(parent: Container, title: String, color: Color, term_id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(150, 44)
	panel.add_theme_stylebox_override(
		"panel",
		UiKit.panel_style(UiKit.COLOR_ROW, UiKit.COLOR_BORDER_DIM, 5, 8, 3)
	)
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

	var header := HBoxContainer.new()
	box.add_child(header)

	var top_lbl := Label.new()
	top_lbl.text = title
	top_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_lbl.add_theme_font_size_override("font_size", 12)
	top_lbl.add_theme_color_override("font_color", color)
	header.add_child(top_lbl)

	var trend_lbl := Label.new()
	trend_lbl.add_theme_font_size_override("font_size", 11)
	trend_lbl.add_theme_color_override("font_color", UiKit.COLOR_MUTED)
	header.add_child(trend_lbl)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 9)
	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.05, 0.02, 0.10, 1.0)
	bar.add_theme_stylebox_override("background", bg_bar)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)

	return {"title": title, "top": top_lbl, "bar": bar, "trend": trend_lbl, "fill": fill, "base_color": color}


func _build_touch_controls() -> void:
	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.anchor_left = 0.0
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = 12.0
	dpad.offset_top = -110.0
	dpad.offset_right = 144.0
	dpad.offset_bottom = -6.0
	dpad.add_theme_constant_override("h_separation", 3)
	dpad.add_theme_constant_override("v_separation", 3)
	add_child(dpad)

	dpad.add_child(Control.new())
	_add_dpad_btn(dpad, "▲", "up")
	dpad.add_child(Control.new())
	_add_dpad_btn(dpad, "◀", "left")
	_add_dpad_btn(dpad, "▼", "down")
	_add_dpad_btn(dpad, "▶", "right")


func _add_dpad_btn(parent: Container, text_str: String, dir_key: String) -> void:
	var btn := UiKit.button(text_str, 13, Vector2(38, 30))
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
		mute_button.text = "🔇 OFF" if is_muted else "🔊 ON"


func _on_game_state_changed() -> void:
	day_ap_label.text = "DAY %d / %d    |    ACTIONS: %s" % [
		GameState.day,
		Rules.mission_days(),
		GameState.ap_dots(),
	]

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
			fill.bg_color = UiKit.COLOR_BAD
		else:
			fill.bg_color = w["base_color"]

	var sh_stars := ""
	for i in range(Rules.max_value("shield")):
		sh_stars += "★" if i < GameState.shield else "☆"
	shield_label.text = "SHIELD\n" + sh_stars

	var sci_goal := maxi(1, int(Rules.win_data().get("three_stars_science", 30)))
	var sci_bars := clampi(int(round(float(GameState.science) / float(sci_goal) * 3.0)), 0, 3)
	var sci_stars := ""
	for i in range(3):
		sci_stars += "★" if i < sci_bars else "☆"
	science_label.text = "SCIENCE\n" + sci_stars

	coach_label.text = GameState.coach_hint()
	end_day_button.disabled = GameState.game_over or GameState.phase != GameState.PHASE_PLAYING


func _on_end_day_pressed() -> void:
	GameState.end_day()


func _on_day5_test_pressed() -> void:
	GameState.run_day5_debug_test()


func _on_menu_pressed() -> void:
	AudioManager.stop_alarm()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
