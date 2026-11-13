extends Control
## Manages the 5 facility dashboards on a CanvasLayer, including storm lockdown at the shelter
## and tap-to-explain buttons for key science terms.

signal dashboard_visibility_changed(is_open: bool)
signal lockdown_requested

var current_facility_id: String = ""

var backdrop: ColorRect
var card_panel: PanelContainer
var title_label: Label
var explain_holder: HBoxContainer
var description_label: Label
var status_label: Label
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
	backdrop.color = Color(0.02, 0.04, 0.08, 0.68)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	card_panel = PanelContainer.new()
	card_panel.anchor_left = 0.5
	card_panel.anchor_right = 0.5
	card_panel.anchor_top = 0.5
	card_panel.anchor_bottom = 0.5
	card_panel.offset_left = -350.0
	card_panel.offset_right = 350.0
	card_panel.offset_top = -235.0
	card_panel.offset_bottom = 235.0
	card_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	add_child(card_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", UiKit.COLOR_WARN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	explain_holder = HBoxContainer.new()
	explain_holder.add_theme_constant_override("separation", 6)
	header.add_child(explain_holder)

	close_button = UiKit.button("Close [X]", 16, Vector2(110, 42))
	close_button.pressed.connect(close_dashboard)
	header.add_child(close_button)

	description_label = UiKit.label("", 16, UiKit.COLOR_MUTED)
	vbox.add_child(description_label)

	vbox.add_child(HSeparator.new())

	status_label = UiKit.label("", 16, UiKit.COLOR_GOOD)
	vbox.add_child(status_label)

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_dashboard()


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
			var dust := GameState.solar_penalty_amount if GameState.solar_penalty_days > 0 else 0
			var eff_solar := maxi(0, Rules.power_solar() - dust)
			description_label.text = "Solar panels collect sunlight (+%d Power/day) and charge the battery." % eff_solar
			var base_c := Rules.power_base_load()
			var ls_c := int(Rules.life_support_mode_data(GameState.life_support_mode).get("cost", 0))
			var sh_c := GameState.shield * Rules.shield_upkeep_per_level()
			var gh_c := int(Rules.greenhouse_mode_data(GameState.greenhouse_mode).get("cost", 0))
			var net := eff_solar - (base_c + ls_c + sh_c + gh_c)
			status_label.text = "Battery: %d / %d PU  |  Forecast Net Balance: %+d PU/day\n(Solar +%d, Base -%d, Life Support -%d, Shield -%d, Greenhouse -%d)" % [
				GameState.battery, GameState.battery_max(), net, eff_solar, base_c, ls_c, sh_c, gh_c,
			]
			_add_action_button("Clean / Repair Solar Panels", "repair_panel", null)
			_add_action_button("Run Science Experiment (+%d Science)" % int(Rules.action_data("experiment").get("science", 0)), "experiment", null)

		"life_support":
			title_label.text = "Life Support"
			_set_explain_terms(["oxygen"])
			description_label.text = "Makes breathable oxygen for the crew! The crew uses %d Oxygen per day." % Rules.consumption_oxygen()
			var ls_data := Rules.life_support_mode_data(GameState.life_support_mode)
			var net_o2 := int(ls_data.get("o2", 0)) - Rules.consumption_oxygen()
			status_label.text = "Oxygen: %d / %d  |  Current Mode: %s (+%d O2/day, Net %+d/day, -%d PU/day)" % [
				GameState.oxygen, Rules.max_value("oxygen"),
				GameState.life_support_mode.capitalize(),
				int(ls_data.get("o2", 0)), net_o2, int(ls_data.get("cost", 0)),
			]
			for mode in ["eco", "normal", "high"]:
				var mdata := Rules.life_support_mode_data(mode)
				_add_action_button(
					"Set Mode: %s (Cost %d PU/day, +%d O2/day)" % [mode.capitalize(), int(mdata.get("cost", 0)), int(mdata.get("o2", 0))],
					"set_life_support",
					mode
				)
			_add_action_button("Emergency Oxygen Boost (+%d O2 now)" % int(Rules.action_data("emergency_oxygen").get("oxygen", 0)), "emergency_oxygen", null)

		"greenhouse":
			title_label.text = "Greenhouse"
			_set_explain_terms(["greenhouse"])
			description_label.text = "Grows fresh food using water and power. Harvest crates arrive in %d days! (Inspired by CSA space food tips)" % Rules.greenhouse_delay_days()
			var gh_data := Rules.greenhouse_mode_data(GameState.greenhouse_mode)
			status_label.text = "Food: %d / %d (-%d/day)  |  Water: %d / %d (+%d recycled/day)\nCurrent Mode: %s (-%d PU/day, -%d Water/day, +%d Food in %d days)" % [
				GameState.food, Rules.max_value("food"), Rules.consumption_food(),
				GameState.water, Rules.max_value("water"), Rules.water_recycle(),
				GameState.greenhouse_mode.capitalize(),
				int(gh_data.get("cost", 0)), int(gh_data.get("water", 0)),
				int(gh_data.get("food", 0)), Rules.greenhouse_delay_days(),
			]
			for mode in ["off", "low", "high"]:
				var mdata := Rules.greenhouse_mode_data(mode)
				_add_action_button(
					"Set Mode: %s (-%d PU, -%d Water -> +%d Food)" % [
						mode.capitalize(), int(mdata.get("cost", 0)), int(mdata.get("water", 0)), int(mdata.get("food", 0))
					],
					"set_greenhouse",
					mode
				)
			_add_action_button("Repair Greenhouse Water Pump", "repair_pump", null)

		"radiation_shelter":
			title_label.text = "Radiation Shelter"
			_set_explain_terms(["shielding", "radiation", "solar_storm"])
			description_label.text = "Protects the crew from solar storms! Each shield level blocks %d%% of storm damage and costs %d PU/day upkeep." % [
				int(round(float(Rules.storm_data().get("shield_reduction", 0.0)) * 100.0)),
				Rules.shield_upkeep_per_level(),
			]
			status_label.text = "Shield Level: %d / %d  |  Crew Health: %d / %d  |  Upkeep: -%d PU/day" % [
				GameState.shield, Rules.max_value("shield"),
				GameState.health, Rules.max_value("health"),
				GameState.shield * Rules.shield_upkeep_per_level(),
			]
			if GameState.phase == GameState.PHASE_STORM:
				var lock_cost := int(Rules.storm_data().get("lockdown_power", 0))
				var lock_btn := UiKit.button("", 18, Vector2(0, 56))
				if GameState.battery >= lock_cost:
					lock_btn.text = ">>> START LOCKDOWN NOW (-%d PU, cuts storm damage in half!) <<<" % lock_cost
				else:
					lock_btn.text = ">>> EMERGENCY LOW-POWER LOCKDOWN (Battery < %d PU: uses remaining power, 25%% protection) <<<" % lock_cost
				lock_btn.pressed.connect(func() -> void:
					close_dashboard()
					lockdown_requested.emit()
				)
				actions_box.add_child(lock_btn)
			_add_action_button("Upgrade Radiation Shield (+1 Level)", "upgrade_shield", null)

		"comms_room":
			title_label.text = "Communications Room"
			_set_explain_terms(["comm_delay"])
			var comms_delay := int(Rules.comms_data().get("delay_days", 0))
			description_label.text = "Talk with Mission Control on Earth! Gameplay simplification: messages take %d days to arrive." % comms_delay
			status_label.text = "Day %d / %d  |  AP Left: %d  |  Messages in Transit: %d" % [
				GameState.day, Rules.mission_days(), GameState.ap, GameState.pending_messages.size(),
			]
			_add_action_button("Request Space Weather Forecast (%d-day reply)" % comms_delay, "forecast", null)
			_add_action_button("Request Mission Control Advice (%d-day reply)" % comms_delay, "advice", null)
			var res_spec: Dictionary = Rules.action_data("resupply")
			var opts: Dictionary = res_spec.get("options", {})
			for res_key in ["food", "oxygen", "water"]:
				if opts.has(res_key):
					_add_action_button(
						"Order %s Resupply (+%d %s in %d days, send by Day %d)" % [
							res_key.capitalize(), int(opts[res_key]), res_key.capitalize(),
							int(res_spec.get("delay", 0)), int(res_spec.get("send_by_day", 0)),
						],
						"resupply",
						res_key
					)

	if not GameState.daily_log.is_empty():
		feedback_label.text = "Latest: " + GameState.daily_log[GameState.daily_log.size() - 1]
	else:
		feedback_label.text = ""


func _add_action_button(label_text: String, action_id: String, param: Variant) -> void:
	var cost_info := GameState.get_action_cost(action_id, param)
	var check := GameState.can_try_action(action_id, param)
	var btn := UiKit.button("", 15, Vector2(0, 42))
	var cost_str := "[%d AP, %d PU]" % [int(cost_info["ap"]), int(cost_info["power"])]
	if bool(check.get("ok", false)):
		btn.text = "%s  %s" % [label_text, cost_str]
		btn.disabled = false
	else:
		btn.text = "%s  %s — %s" % [label_text, cost_str, String(check.get("reason", ""))]
		btn.disabled = true
	btn.pressed.connect(func() -> void:
		GameState.try_action(action_id, param)
	)
	actions_box.add_child(btn)
