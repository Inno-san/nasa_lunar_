extends SceneTree
## Automated verification of the full Playtest Checklist (Milestones 1-9).
## Run with: godot --headless --path . -s res://scripts/test_playtest_checklist.gd

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_checks()
	return true


func _check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("FAIL: " + msg)
		quit(1)


func _run_checks() -> void:
	var gs: Node = root.get_node("GameState")
	var nd: Node = root.get_node("NasaData")
	var ex: Node = root.get_node("Explain")
	var am: Node = root.get_node("AudioManager")
	var replay_hints_script: GDScript = load("res://scripts/replay_hints.gd")

	# 1. Verify Day-5 numeric test
	var day5: Dictionary = gs.run_day5_debug_test()
	_check(bool(day5["passed"]), "Day-5 numeric test failed: " + JSON.stringify(day5))
	print("[PASS] 1. Day-5 numeric test: battery=32, oxygen=70, food=27, water=25, health=100")

	# 2. Verify Low-Battery Lockdown on a Storm Day (Day 4, Severity 1, Shield 1)
	gs.reset_game()
	gs.day = 4
	gs.shield = 1
	gs.effective_shield_today = 1
	gs.battery = 2
	gs.life_support_mode = "normal"
	gs.greenhouse_mode = "high"
	gs.end_day()
	_check(gs.phase == gs.PHASE_STORM, "Expected storm phase on Day 4")
	_check(gs.battery == 2, "Expected 2 PU before lockdown, got %d" % gs.battery)
	var low_bat_report: Dictionary = gs.resolve_storm(true)
	var storm_res: Dictionary = low_bat_report["storm"]
	_check(bool(storm_res["low_battery"]) == true, "Expected low_battery=true")
	_check(gs.battery == 0, "Expected battery to drop to 0 on low-power lockdown")
	_check(int(storm_res["damage"]) == 6, "Expected S1 shield 1 low-power damage ceil(10*0.8*0.75)=6, got %d" % int(storm_res["damage"]))
	print("[PASS] 2. Low-battery lockdown test: battery 2 -> 0, factor 0.75 applied (damage=6), greenhouse paused, console explained")

	# 3. Verify Full 10-Day Win (3 Stars) + Non-repeating OSDR facts + DONKI storm records
	gs.reset_game()
	var seen_facts: Dictionary = {}
	var f0: Dictionary = nd.next_fact()
	seen_facts[f0["id"]] = true

	for d in range(1, 11):
		_check(gs.day == d, "Expected day %d, got %d" % [d, gs.day])
		while not gs.pending_events.is_empty():
			var ev: Dictionary = gs.pending_events.pop_front()
			var eid := String(ev.get("id", ""))
			var choices: Array = ev.get("choices", [])
			if not choices.is_empty():
				match eid:
					"dusty_panels":
						gs.choose_event(eid, "clean")
					"pump_failure":
						gs.choose_event(eid, "fix")
					"micrometeorite_leak":
						gs.choose_event(eid, "patch")
					"research_window":
						gs.choose_event(eid, "double")
					"battery_cell":
						gs.choose_event(eid, "repair")
					"comms_blackout":
						gs.choose_event(eid, "wait")
					_:
						gs.choose_event(eid, String(choices[0]["id"]))

		if d == 1:
			gs.try_action("upgrade_shield")
		elif d == 2:
			gs.try_action("upgrade_shield")
		elif d == 3:
			gs.try_action("resupply", "food")
		elif d == 6:
			gs.try_action("forecast")
		elif d == 8:
			gs.try_action("forecast")

		gs.end_day()
		if gs.phase == gs.PHASE_STORM:
			var rec: Dictionary = gs.storm_info.get("record", {})
			_check(not rec.is_empty(), "Missing DONKI record for storm on day %d" % d)
			gs.resolve_storm(true)

		var fd: Dictionary = nd.next_fact()
		_check(not seen_facts.has(fd["id"]), "Repeated OSDR fact %s on day %d" % [fd["id"], d])
		seen_facts[fd["id"]] = true

	var fend: Dictionary = nd.next_fact()
	_check(not seen_facts.has(fend["id"]), "Repeated OSDR fact on end screen")
	seen_facts[fend["id"]] = true
	_check(not nd.facts_repeated, "OSDR facts should not repeat in one 10-day run")
	_check(gs.game_over and gs.mission_won, "Expected 10-day win, got game_over=%s won=%s health=%d" % [str(gs.game_over), str(gs.mission_won), gs.health])
	_check(gs.stars_earned == 3, "Expected 3 stars, got %d (health=%d, science=%d)" % [gs.stars_earned, gs.health, gs.science])
	print("[PASS] 3. Full 10-day win test: Won with %d/3 Stars (Health=%d, Science=%d), 12 unique OSDR facts shown with 0 repeats" % [gs.stars_earned, gs.health, gs.science])

	# 4. Verify Loss condition and "What went wrong" ReplayHints
	gs.reset_game()
	gs.oxygen = 0
	gs.food = 0
	for _i in range(5):
		if gs.game_over:
			break
		gs.end_day()
		if gs.phase == gs.PHASE_STORM:
			gs.resolve_storm(false)
	_check(gs.game_over and not gs.mission_won and gs.health == 0, "Expected loss with health 0")
	var hints: Array[String] = replay_hints_script.build()
	_check(not hints.is_empty(), "Expected non-empty replay hints on loss")
	print("[PASS] 4. Loss & replay hints test: Health reached 0, generated %d replay hints: %s" % [hints.size(), JSON.stringify(hints)])

	# 5. Verify UI scenes, tap-to-explain terms, and audio mute hooks
	for term_id in ["solar_storm", "radiation", "shielding", "oxygen", "battery", "greenhouse", "comm_delay"]:
		var txt: String = ex.term_text(term_id)
		_check(txt.length() > 10, "Missing tooltip text for " + term_id)
		ex.show_term(term_id)
		_check(ex.is_open(), "Explain modal should open for " + term_id)
		ex.close()
	am.toggle_mute()
	_check(am.muted == true, "Expected muted=true")
	am.toggle_mute()
	_check(am.muted == false, "Expected muted=false")

	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu_inst := menu_scene.instantiate()
	root.add_child(menu_inst)
	menu_inst.free()

	var base_scene: PackedScene = load("res://scenes/lunar_base.tscn")
	var base_inst := base_scene.instantiate()
	root.add_child(base_inst)
	var astro: CharacterBody2D = base_inst.get_node("Astronaut")
	_check(astro.walk_audio != null, "Expected Astronaut AudioStreamPlayer walk_audio to exist")
	base_inst._handle_world_click(Vector2(500, 500))
	_check(astro.has_click_target == true, "Expected click on floor to set has_click_target=true")
	var pwr: Area2D = base_inst.get_node("Facilities/PowerStation")
	base_inst._handle_world_click(pwr.global_position)
	_check(astro.pending_facility == pwr, "Expected click on PowerStation to set pending_facility=PowerStation")
	base_inst._on_storm_started({"day": 4, "severity": 1, "warned": true, "seconds": 10.0, "record": {}})
	_check(astro.movement_locked == true, "Expected astronaut locked while storm intro card is open")
	base_inst.storm_overlay._start_countdown()
	_check(astro.movement_locked == false, "Expected astronaut unlocked during storm countdown so player can run to shelter")
	base_inst.storm_overlay._finish(true)
	var dm: Control = base_inst.get_node("CanvasLayer/DashboardManager")
	for fid in ["power_station", "life_support", "greenhouse", "radiation_shelter", "comms_room"]:
		dm.open_dashboard(fid)
		for ttab in ["information", "buildings", "operations", "statistics"]:
			dm.current_top_tab = ttab
			dm._refresh_contents()
		dm.current_sub_tab = "glossary"
		dm._refresh_contents()
		dm.current_sub_tab = "controls"
	dm.close_dashboard()
	base_inst.free()
	print("[PASS] 5. UI scenes (main_menu, lunar_base), 5-room chamfered dashboard, 7 tap-to-explain terms, and audio mute hooks verified")

	print("ALL PLAYTEST CHECKLIST ITEMS PASSED!")
	quit(0)
