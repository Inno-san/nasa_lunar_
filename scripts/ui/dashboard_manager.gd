extends Control
## Visual, zero-math facility dashboards.
## Every option explains what it does in plain words with no formulas or calculations needed.

signal dashboard_visibility_changed(is_open: bool)
signal lockdown_requested

var current_facility_id: String = ""

var backdrop: ColorRect
var card_panel: PanelContainer
var title_label: Label
var explain_holder: HBoxContainer
var description_label: Label
var status_label: Label
var status_bar: ProgressBar
var actions_box: VBoxContainer
var feedback_label: Label
var close_button: Button


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_modal()
	GameState.state_changed.connect(_on_state_changed)


func _build_modal() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.08, 0.72)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	card_panel = PanelContainer.new()
	card_panel.anchor_left = 0.5
	card_panel.anchor_right = 0.5
	card_panel.anchor_top = 0.5
	card_panel.anchor_bottom = 0.5
	card_panel.offset_left = -360.0
	card_panel.offset_right = 360.0
	card_panel.offset_top = -245.0
	card_panel.offset_bottom = 245.0
	card_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	add_child(card_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", UiKit.COLOR_WARN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	explain_holder = HBoxContainer.new()
	explain_holder.add_theme_constant_override("separation", 6)
	header.add_child(explain_holder)

	close_button = UiKit.button("Close [X]", 16, Vector2(110, 42))
	close_button.pressed.connect(close_dashboard)
	header.add_child(close_button)

	description_label = UiKit.label("", 17, UiKit.COLOR_MUTED)
	vbox.add_child(description_label)

	status_bar = ProgressBar.new()
	status_bar.show_percentage = false
	status_bar.custom_minimum_size = Vector2(0, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 0.55)
	fill.set_corner_radius_all(4)
	status_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(status_bar)

	status_label = UiKit.label("", 17, UiKit.COLOR_GOOD)
	vbox.add_child(status_label)

	vbox.add_child(HSeparator.new())

	actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 8)
	actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(actions_box)

	feedback_label = UiKit.label("", 15, UiKit.COLOR_WARN)
	vbox.add_child(feedback_label)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_dashboard()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and ev_pressed(event):
		close_dashboard()


func ev_pressed(event: InputEventMouseButton) -> bool:
	return event.pressed


func open_dashboard(facility_id: String) -> void:
	current_facility_id = facility_id
	visible = true
	dashboard_visibility_changed.emit(true)
	_refresh_contents()


func close_dashboard() -> void:
	if not visible:
		return
	visible = false
	current_facility_id = ""
	dashboard_visibility_changed.emit(false)


func _on_state_changed() -> void:
	if visible and not current_facility_id.is_empty():
		_refresh_contents()


func _set_explain_terms(terms: Array) -> void:
	UiKit.clear_children(explain_holder)
	for term_id in terms:
		var btn := Explain.make_button(String(term_id))
		btn.text = "? " + Explain.term_title(String(term_id))
		btn.custom_minimum_size = Vector2(0, 38)
		explain_holder.add_child(btn)


func _refresh_contents() -> void:
	UiKit.clear_children(actions_box)

	match current_facility_id:
		"power_station":
			title_label.text = "Power Station"
			_set_explain_terms(["battery"])
			description_label.text = "Solar panels collect sunlight every day to charge the base Battery."
			status_bar.visible = true
			status_bar.max_value = GameState.battery_max()
			status_bar.value = GameState.battery
			status_label.text = "Battery is %s (%s each day)   |   Actions left today: %s" % [
				GameState.meter_word("battery"), GameState.meter_trend("battery"), GameState.ap_dots()
			]
			_add_action_button("Clean Solar Panels — Keeps sunlight power strong", "repair_panel", null)
			_add_action_button("Do a Science Experiment — Helps you earn 3 Stars!", "experiment", null)

		"life_support":
			title_label.text = "Life Support"
			_set_explain_terms(["oxygen"])
			description_label.text = "Makes fresh Oxygen so the crew can breathe!"
			status_bar.visible = true
			status_bar.max_value = Rules.max_value("oxygen")
			status_bar.value = GameState.oxygen
			status_label.text = "Oxygen is %s (%s)   |   Current setting: %s" % [
				GameState.meter_word("oxygen"), GameState.meter_trend("oxygen"), GameState.life_support_mode.capitalize()
			]
			_add_action_button("Eco Mode — Saves power, but Oxygen slowly goes DOWN", "set_life_support", "eco")
			_add_action_button("Normal Mode (Recommended) — Keeps Oxygen steady every day", "set_life_support", "normal")
			_add_action_button("High Mode — Fills Oxygen UP every day (uses more power)", "set_life_support", "high")
			_add_action_button("Emergency Air Boost — Adds fresh Oxygen right now!", "emergency_oxygen", null)

		"greenhouse":
			title_label.text = "Greenhouse"
			_set_explain_terms(["greenhouse"])
			description_label.text = "Grows fresh food for the crew! Plants take a couple of days to grow into a harvest."
			status_bar.visible = true
			status_bar.max_value = Rules.max_value("food")
			status_bar.value = GameState.food
			status_label.text = "Food is %s   |   Water is %s   |   Current setting: %s" % [
				GameState.meter_word("food"), GameState.meter_word("water"), GameState.greenhouse_mode.capitalize()
			]
			_add_action_button("Off — Saves all water and power, but grows no food", "set_greenhouse", "off")
			_add_action_button("Low Mode (Recommended) — Grows a steady small harvest", "set_greenhouse", "low")
			_add_action_button("High Mode — Grows a big harvest! (uses more water & power)", "set_greenhouse", "high")
			_add_action_button("Fix Water Pump — Repairs the pump if it broke", "repair_pump", null)

		"radiation_shelter":
			title_label.text = "Radiation Shelter"
			_set_explain_terms(["shielding", "radiation", "solar_storm"])
			description_label.text = "Keeps the crew safe when a solar storm hits the Moon!"
			status_bar.visible = true
			status_bar.max_value = Rules.max_value("shield")
			status_bar.value = GameState.shield
			var sh_stars := ""
			for i in range(Rules.max_value("shield")):
				sh_stars += "★ " if i < GameState.shield else "☆ "
			status_label.text = "Shield Strength: %s   |   Crew Health: %s" % [
				sh_stars.strip_edges(), GameState.meter_word("health")
			]
			if GameState.phase == GameState.PHASE_STORM:
				var lock_btn := UiKit.button(">>> HIDE IN SHELTER & LOCK DOWN NOW! <<<", 20, Vector2(0, 60))
				lock_btn.pressed.connect(func() -> void:
					close_dashboard()
					lockdown_requested.emit()
				)
				actions_box.add_child(lock_btn)
			_add_action_button("Upgrade Shield — Adds stronger protection against storms!", "upgrade_shield", null)

		"comms_room":
			title_label.text = "Communications Room"
			_set_explain_terms(["comm_delay"])
			description_label.text = "Send radio messages to Mission Control on Earth! Replies arrive after a short travel delay."
			status_bar.visible = false
			status_label.text = "Messages travelling between Earth & Moon: %d   |   Actions left: %s" % [
				GameState.pending_messages.size(), GameState.ap_dots()
			]
			_add_action_button("Ask Earth for a Storm Forecast — Warns you before big storms hit!", "forecast", null)
			_add_action_button("Ask Mission Control for Advice — Sends a helpful tip", "advice", null)
			_add_action_button("Call a Supply Rocket: Extra Food — Drops a crate of Food", "resupply", "food")
			_add_action_button("Call a Supply Rocket: Extra Oxygen — Drops a tank of Oxygen", "resupply", "oxygen")
			_add_action_button("Call a Supply Rocket: Extra Water — Drops a tank of Water", "resupply", "water")

	if not GameState.daily_log.is_empty():
		feedback_label.text = "Latest: " + GameState.daily_log[GameState.daily_log.size() - 1]
	else:
		feedback_label.text = ""


func _add_action_button(label_text: String, action_id: String, param: Variant) -> void:
	var check := GameState.can_try_action(action_id, param)
	var btn := UiKit.button("", 16, Vector2(0, 44))
	if bool(check.get("ok", false)):
		btn.text = "▶  " + label_text
		btn.disabled = false
	else:
		btn.text = "%s   (%s)" % [label_text, String(check.get("reason", ""))]
		btn.disabled = true
	btn.pressed.connect(func() -> void:
		GameState.try_action(action_id, param)
	)
	actions_box.add_child(btn)
