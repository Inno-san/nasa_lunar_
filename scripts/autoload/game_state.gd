extends Node
## Autoload managing all mission meters, AP, days, actions, and day-end resolution.
## All numbers are read dynamically from Rules (data/rules.json).

signal state_changed
signal day_ended(report: Dictionary)

var day: int = 1
var ap: int = 0

var battery: int = 0
var oxygen: int = 0
var food: int = 0
var water: int = 0
var health: int = 0
var shield: int = 0
var science: int = 0

var life_support_mode: String = "normal"
var greenhouse_mode: String = "low"
var effective_shield_today: int = 0
var storm_occurred_today: bool = false
var lockdown_paused_greenhouse_today: bool = false

# Maps delivery day (int) -> food amount (int) from Greenhouse delayed production
var food_crates: Dictionary = {}

# Delayed comms/resupply queue: Array of Dictionaries {deliver_day, type, payload, text}
var pending_messages: Array[Dictionary] = []

# Plain-language feedback log for kids
var daily_log: Array[String] = []
var last_day_report: Dictionary = {}

var game_over: bool = false
var mission_won: bool = false
var stars_earned: int = 0


func _ready() -> void:
	reset_game()


func reset_game() -> void:
	day = 1
	ap = Rules.ap_per_day()

	battery = Rules.start_value("battery")
	oxygen = Rules.start_value("oxygen")
	food = Rules.start_value("food")
	water = Rules.start_value("water")
	health = Rules.start_value("health")
	shield = Rules.start_value("shield")
	science = 0

	life_support_mode = "normal"
	greenhouse_mode = "low"
	effective_shield_today = shield
	storm_occurred_today = false
	lockdown_paused_greenhouse_today = false

	food_crates.clear()
	pending_messages.clear()
	daily_log.clear()
	last_day_report.clear()

	game_over = false
	mission_won = false
	stars_earned = 0

	_add_log("Mission Day 1 started! Walk with WASD/Arrows or click facilities, press E to open dashboards.")
	state_changed.emit()


func _add_log(message: String) -> void:
	daily_log.append(message)


func get_action_cost(action_id: String, param: Variant = null) -> Dictionary:
	var normalized := _normalize_action(action_id, param)
	var base_id: String = normalized["id"]
	var spec: Dictionary = Rules.action_data(base_id)
	return {
		"id": base_id,
		"param": normalized["param"],
		"ap": int(spec.get("ap", 0)),
		"power": int(spec.get("power", 0)),
		"spec": spec
	}


func _normalize_action(action_id: String, param: Variant = null) -> Dictionary:
	if action_id.begins_with("set_life_support_"):
		return {
			"id": "set_life_support",
			"param": action_id.trim_prefix("set_life_support_")
		}
	if action_id.begins_with("set_greenhouse_"):
		return {
			"id": "set_greenhouse",
			"param": action_id.trim_prefix("set_greenhouse_")
		}
	if action_id.begins_with("resupply_"):
		return {
			"id": "resupply",
			"param": action_id.trim_prefix("resupply_")
		}
	return {"id": action_id, "param": param}


func can_try_action(action_id: String, param: Variant = null) -> Dictionary:
	if game_over:
		return {"ok": false, "reason": "The mission has ended."}

	var info := get_action_cost(action_id, param)
	var base_id: String = info["id"]
	var target_param: Variant = info["param"]
	var ap_cost: int = info["ap"]
	var power_cost: int = info["power"]
	var spec: Dictionary = info["spec"]

	if spec.is_empty():
		return {"ok": false, "reason": "Unknown action: " + action_id}

	var missing: Array[String] = []
	if ap < ap_cost:
		missing.append("Need %d AP (you have %d)" % [ap_cost, ap])
	if battery < power_cost:
		missing.append("Need %d Battery power (you have %d)" % [power_cost, battery])
	if not missing.is_empty():
		return {"ok": false, "reason": ", ".join(missing)}

	match base_id:
		"set_life_support":
			var mode_str := String(target_param if target_param != null else "")
			if mode_str not in ["eco", "normal", "high"]:
				return {"ok": false, "reason": "Choose Eco, Normal, or High mode."}
			if life_support_mode == mode_str:
				return {"ok": false, "reason": "Life Support is already on %s." % mode_str.capitalize()}
		"set_greenhouse":
			var gh_str := String(target_param if target_param != null else "")
			if gh_str not in ["off", "low", "high"]:
				return {"ok": false, "reason": "Choose Off, Low, or High mode."}
			if greenhouse_mode == gh_str:
				return {"ok": false, "reason": "Greenhouse is already on %s." % gh_str.capitalize()}
		"upgrade_shield":
			if shield >= Rules.max_value("shield"):
				return {"ok": false, "reason": "Shield is already at maximum level (%d)." % Rules.max_value("shield")}
		"resupply":
			var send_by := int(spec.get("send_by_day", 0))
			if day > send_by:
				return {"ok": false, "reason": "Resupply rockets can only be requested up to Day %d." % send_by}
			var res_type := String(target_param if target_param != null else "food")
			var options: Dictionary = spec.get("options", {})
			if not options.has(res_type):
				return {"ok": false, "reason": "Choose oxygen, food, or water for resupply."}

	return {"ok": true, "reason": "Ready"}


func try_action(action_id: String, param: Variant = null) -> bool:
	var check := can_try_action(action_id, param)
	if not check.get("ok", false):
		_add_log("Cannot perform action: " + String(check.get("reason", "")))
		state_changed.emit()
		return false

	var info := get_action_cost(action_id, param)
	var base_id: String = info["id"]
	var target_param: Variant = info["param"]
	var ap_cost: int = info["ap"]
	var power_cost: int = info["power"]
	var spec: Dictionary = info["spec"]

	ap -= ap_cost
	battery = clampi(battery - power_cost, 0, Rules.max_value("battery"))

	match base_id:
		"experiment":
			var sci_gain := int(spec.get("science", 0))
			science += sci_gain
			_add_log("Ran science experiment! +%d Science (-%d AP, -%d Power)." % [sci_gain, ap_cost, power_cost])
		"set_life_support":
			var new_ls := String(target_param)
			life_support_mode = new_ls
			_add_log("Life Support switched to %s mode (-%d AP)." % [new_ls.capitalize(), ap_cost])
		"emergency_oxygen":
			var o2_gain := int(spec.get("oxygen", 0))
			oxygen = clampi(oxygen + o2_gain, 0, Rules.max_value("oxygen"))
			_add_log("Emergency Oxygen tank used! +%d Oxygen (-%d AP, -%d Power)." % [o2_gain, ap_cost, power_cost])
		"set_greenhouse":
			var new_gh := String(target_param)
			greenhouse_mode = new_gh
			_add_log("Greenhouse switched to %s mode (-%d AP)." % [new_gh.capitalize(), ap_cost])
		"upgrade_shield":
			shield = clampi(shield + 1, 0, Rules.max_value("shield"))
			effective_shield_today = shield
			_add_log("Radiation Shield upgraded to Level %d! (-%d AP, -%d Power)." % [shield, ap_cost, power_cost])
		"repair_pump":
			_add_log("Repaired Greenhouse water pump! (-%d AP, -%d Power)." % [ap_cost, power_cost])
		"repair_panel":
			_add_log("Cleaned and repaired solar panels! (-%d AP)." % ap_cost)
		"forecast":
			var delay := int(Rules.comms_data().get("delay_days", 0))
			var arrival := day + delay
			pending_messages.append({
				"deliver_day": arrival,
				"type": "forecast",
				"text": "Earth Weather Forecast arrived ( covers Days %d to %d )." % [arrival, arrival + delay]
			})
			_add_log("Requested storm forecast from Earth (-%d AP, -%d Power). Reply arrives start of Day %d." % [ap_cost, power_cost, arrival])
		"advice":
			var delay := int(Rules.comms_data().get("delay_days", 0))
			var arrival := day + delay
			pending_messages.append({
				"deliver_day": arrival,
				"type": "advice",
				"text": "Mission Control Advice arrived for Day %d!" % arrival
			})
			_add_log("Asked Mission Control for advice (-%d AP, -%d Power). Reply arrives in %d days." % [ap_cost, power_cost, delay])
		"resupply":
			var res_type := String(target_param if target_param != null else "food")
			var delay := int(spec.get("delay", 0))
			var options: Dictionary = spec.get("options", {})
			var amount := int(options.get(res_type, 0))
			var arrival := day + delay
			pending_messages.append({
				"deliver_day": arrival,
				"type": "resupply",
				"resource": res_type,
				"amount": amount,
				"text": "Resupply pod landed! +%d %s." % [amount, res_type.capitalize()]
			})
			_add_log("Ordered %s resupply (-%d AP, -%d Power). Arrives in %d days (Day %d)." % [res_type.capitalize(), ap_cost, power_cost, delay, arrival])

	state_changed.emit()
	return true


## Runs the full 7-step day-end resolution order defined in docs/game_mechanics.md.
func end_day(advance_to_next_day: bool = true) -> Dictionary:
	if game_over:
		return last_day_report

	var resolved_day := day
	var notes: Array[String] = []
	var cuts: Array[String] = []

	var eff_ls_mode := life_support_mode
	var eff_gh_mode := greenhouse_mode
	var eff_shield := shield

	if lockdown_paused_greenhouse_today and eff_gh_mode != "off":
		eff_gh_mode = "off"
		notes.append("Storm lockdown paused the Greenhouse today.")

	# Check water sufficiency before Greenhouse runs:
	# "if too low, greenhouse drops one level and the player is told."
	var needed_water := int(Rules.greenhouse_mode_data(eff_gh_mode).get("water", 0))
	if water < needed_water and eff_gh_mode != "off":
		var dropped_mode := _drop_greenhouse_level(eff_gh_mode)
		greenhouse_mode = dropped_mode
		eff_gh_mode = dropped_mode
		var drop_msg := "Water was too low (%d), so Greenhouse dropped one level to %s." % [water, dropped_mode.capitalize()]
		cuts.append(drop_msg)
		notes.append(drop_msg)

	# --- STEP 1: POWER ---
	# Payment order: base load, Life Support, shield upkeep, Greenhouse.
	# If short, cut in rules.json shortage_order:
	# (1) greenhouse -> off
	# (2) life_support_eco -> eco
	# (3) shield_upkeep -> shield = 0 for storms today
	# (4) life_support_off -> off
	var solar_gain := Rules.power_solar()
	var available_power := battery + solar_gain

	var base_cost := Rules.power_base_load()
	var ls_cost := _get_ls_cost(eff_ls_mode)
	var shield_cost := eff_shield * Rules.shield_upkeep_per_level()
	var gh_cost := int(Rules.greenhouse_mode_data(eff_gh_mode).get("cost", 0))
	var total_power_cost := base_cost + ls_cost + shield_cost + gh_cost

	if available_power < total_power_cost:
		for cut_step in Rules.shortage_order():
			if available_power >= total_power_cost:
				break
			match String(cut_step):
				"greenhouse":
					if eff_gh_mode != "off":
						eff_gh_mode = "off"
						gh_cost = 0
						var msg := "Power shortage Cut #1: Greenhouse turned Off today because battery + solar could not cover all systems."
						cuts.append(msg)
						notes.append(msg)
				"life_support_eco":
					if eff_ls_mode != "eco" and eff_ls_mode != "off":
						eff_ls_mode = "eco"
						ls_cost = _get_ls_cost("eco")
						var msg := "Power shortage Cut #2: Life Support lowered to Eco mode today to save power."
						cuts.append(msg)
						notes.append(msg)
				"shield_upkeep":
					if eff_shield > 0:
						eff_shield = 0
						shield_cost = 0
						var msg := "Power shortage Cut #3: Radiation Shield upkeep suspended today (Shield is Level 0 for storms today)."
						cuts.append(msg)
						notes.append(msg)
				"life_support_off":
					if eff_ls_mode != "off":
						eff_ls_mode = "off"
						ls_cost = 0
						var msg := "Power shortage Cut #4: Life Support shut off completely today due to critical power loss!"
						cuts.append(msg)
						notes.append(msg)
			total_power_cost = base_cost + ls_cost + shield_cost + gh_cost

	effective_shield_today = eff_shield
	battery = clampi(available_power - total_power_cost, 0, Rules.max_value("battery"))

	# --- STEP 2: OXYGEN ---
	var ls_o2 := _get_ls_o2(eff_ls_mode)
	var o2_consumed := Rules.consumption_oxygen()
	var o2_delta := ls_o2 - o2_consumed
	oxygen = clampi(oxygen + o2_delta, 0, Rules.max_value("oxygen"))

	# --- STEP 3: FOOD (add crates, subtract 8) ---
	var arriving_crates := int(food_crates.get(resolved_day, 0))
	if food_crates.has(resolved_day):
		food_crates.erase(resolved_day)

	var gh_food_produced := int(Rules.greenhouse_mode_data(eff_gh_mode).get("food", 0))
	if gh_food_produced > 0:
		var delivery_day := resolved_day + Rules.greenhouse_delay_days()
		food_crates[delivery_day] = int(food_crates.get(delivery_day, 0)) + gh_food_produced

	var food_consumed := Rules.consumption_food()
	food = clampi(food + arriving_crates - food_consumed, 0, Rules.max_value("food"))

	# --- STEP 4: WATER ---
	var gh_water_used := int(Rules.greenhouse_mode_data(eff_gh_mode).get("water", 0))
	var water_recycled := Rules.water_recycle()
	water = clampi(water - gh_water_used + water_recycled, 0, Rules.max_value("water"))

	# If water after recycle is now too low for next day's configured greenhouse mode, drop one level & inform player
	var next_needed_water := int(Rules.greenhouse_mode_data(greenhouse_mode).get("water", 0))
	if water < next_needed_water and greenhouse_mode != "off":
		var new_mode := _drop_greenhouse_level(greenhouse_mode)
		var water_msg := "Water is running low (%d left), so Greenhouse dropped to %s." % [water, new_mode.capitalize()]
		greenhouse_mode = new_mode
		cuts.append(water_msg)
		notes.append(water_msg)

	# --- STEP 5: STORM PHASE ---
	# EventManager hooks into storm phase in Milestones 6-7; tracked via storm_occurred_today.

	# --- STEP 6: HEALTH (penalties; else if no storm +3) ---
	var penalties := Rules.penalties_data()
	var had_penalty := false
	if oxygen <= 0:
		var o2_pen := int(penalties.get("oxygen_zero", 0))
		health -= o2_pen
		had_penalty = true
		notes.append("Oxygen hit 0! Crew Health dropped by %d." % o2_pen)
	if food <= 0:
		var food_pen := int(penalties.get("food_zero", 0))
		health -= food_pen
		had_penalty = true
		notes.append("Food hit 0! Crew Health dropped by %d." % food_pen)
	if not had_penalty and not storm_occurred_today:
		var heal := int(penalties.get("daily_heal", 0))
		health += heal
	health = clampi(health, 0, Rules.max_value("health"))

	# Check loss / win conditions
	if health <= 0:
		game_over = true
		mission_won = false
		stars_earned = 0
		notes.append("Crew health reached 0. Mission ended — try again!")
	elif resolved_day >= Rules.mission_days():
		game_over = true
		var win_spec := Rules.win_data()
		var min_h := int(win_spec.get("min_health", 0))
		var two_h := int(win_spec.get("two_stars_health", 0))
		var three_sci := int(win_spec.get("three_stars_science", 0))
		if health >= min_h:
			mission_won = true
			stars_earned = 1
			if health >= two_h:
				stars_earned = 2
				if science >= three_sci:
					stars_earned = 3
			notes.append("Day %d complete! Mission Success with %d Star(s)!" % [resolved_day, stars_earned])
		else:
			mission_won = false
			stars_earned = 0
			notes.append("Day %d finished with Health %d (needed %d). Try again!" % [resolved_day, health, min_h])

	# --- STEP 7: NEXT DAY (refill AP, deliver messages, show event) ---
	if advance_to_next_day and not game_over:
		day += 1
		ap = Rules.ap_per_day()
		storm_occurred_today = false
		lockdown_paused_greenhouse_today = false
		effective_shield_today = shield
		_deliver_messages_for_day(day, notes)

	last_day_report = {
		"resolved_day": resolved_day,
		"battery": battery,
		"oxygen": oxygen,
		"food": food,
		"water": water,
		"health": health,
		"shield": shield,
		"effective_shield_today": effective_shield_today,
		"science": science,
		"cuts": cuts,
		"notes": notes
	}

	var summary_line := "Day %d resolved -> Battery %d, O2 %d, Food %d, Water %d, Health %d." % [
		resolved_day, battery, oxygen, food, water, health
	]
	_add_log(summary_line)
	for cut_text in cuts:
		_add_log(cut_text)

	day_ended.emit(last_day_report)
	state_changed.emit()
	return last_day_report


func _deliver_messages_for_day(target_day: int, notes: Array[String]) -> void:
	var remaining: Array[Dictionary] = []
	for msg in pending_messages:
		if int(msg.get("deliver_day", 0)) <= target_day:
			if String(msg.get("type", "")) == "resupply":
				var res := String(msg.get("resource", ""))
				var amt := int(msg.get("amount", 0))
				match res:
					"oxygen":
						oxygen = clampi(oxygen + amt, 0, Rules.max_value("oxygen"))
					"food":
						food = clampi(food + amt, 0, Rules.max_value("food"))
					"water":
						water = clampi(water + amt, 0, Rules.max_value("water"))
			var text := String(msg.get("text", "Message from Earth arrived."))
			notes.append(text)
			_add_log(text)
		else:
			remaining.append(msg)
	pending_messages = remaining


func _get_ls_cost(mode: String) -> int:
	if mode == "off":
		return 0
	return int(Rules.life_support_mode_data(mode).get("cost", 0))


func _get_ls_o2(mode: String) -> int:
	if mode == "off":
		return 0
	return int(Rules.life_support_mode_data(mode).get("o2", 0))


func _drop_greenhouse_level(mode: String) -> String:
	if mode == "high":
		return "low"
	return "off"


## Reproduces the Day-5 worked example in docs/game_mechanics.md:
## Start: battery 50, oxygen 70, food 30, water 26, shield 2, LS Normal, GH Low.
## Actions: pump fix (2 AP, 8 PU), forecast (1 AP, 4 PU), experiment (2 AP, 10 PU) -> battery 28.
## Resolution: power 28+36-6-14-8-4 = 32; oxygen 70; food 30+5-8 = 27; water 26-3+2 = 25; health 100.
func run_day5_debug_test() -> Dictionary:
	reset_game()

	day = 5
	ap = Rules.ap_per_day()
	battery = 50
	oxygen = 70
	food = 30
	water = 26
	shield = 2
	effective_shield_today = 2
	health = Rules.start_value("health")
	science = 0
	life_support_mode = "normal"
	greenhouse_mode = "low"

	# Crate produced 2 days earlier (Day 3) on GH Low arrives on Day 5:
	food_crates.clear()
	food_crates[5] = int(Rules.greenhouse_mode_data("low").get("food", 0))

	var act1 := try_action("repair_pump")
	var act2 := try_action("forecast")
	var act3 := try_action("experiment")
	var battery_after_actions := battery

	var report := end_day()

	var passed := (
		act1 and act2 and act3
		and battery_after_actions == 28
		and battery == 32
		and oxygen == 70
		and food == 27
		and water == 25
		and health == 100
	)

	var result := {
		"passed": passed,
		"battery_after_actions": battery_after_actions,
		"battery": battery,
		"oxygen": oxygen,
		"food": food,
		"water": water,
		"health": health,
		"expected": {
			"battery_after_actions": 28,
			"battery": 32,
			"oxygen": 70,
			"food": 27,
			"water": 25,
			"health": 100
		},
		"report": report
	}

	var status_str := "PASS" if passed else "FAIL"
	var log_str := "[Day-5 Debug Test: %s] After actions battery=%d (exp 28) | End of day: battery=%d (exp 32), oxygen=%d (exp 70), food=%d (exp 27), water=%d (exp 25), health=%d (exp 100)" % [
		status_str, battery_after_actions, battery, oxygen, food, water, health
	]
	print(log_str)
	_add_log(log_str)
	state_changed.emit()
	return result

