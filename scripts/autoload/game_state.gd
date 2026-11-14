extends Node
## Owns every meter, the day, action points, actions and the day-end resolution.
## All numbers come from Rules (data/rules.json) or EventManager (data/events.json).

signal state_changed
signal day_ended(report: Dictionary)
signal storm_started(info: Dictionary)

const PHASE_PLAYING := "playing"
const PHASE_STORM := "storm"
const METER_KEYS := ["battery", "oxygen", "food", "water", "health"]

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

var phase: String = PHASE_PLAYING
var game_over: bool = false
var mission_won: bool = false
var stars_earned: int = 0

# Problems started by daily events (see events.json). Each lasts a number of days.
var solar_penalty_amount: int = 0
var solar_penalty_days: int = 0
var pump_output_percent: int = 100
var pump_fault_days: int = 0
var oxygen_leak_amount: int = 0
var oxygen_leak_days: int = 0
var battery_cap: int = 0
var comms_blocked_today: bool = false
var comms_extra_delay: int = 0

var food_crates: Dictionary = {}  # delivery day -> food amount
var pending_messages: Array[Dictionary] = []  # {deliver_day, type, text, ...}
var forecast_storm_days: Array[int] = []  # storm days Earth has told us about
var pending_events: Array = []  # events the player must answer today

var storm_info: Dictionary = {}
var daily_log: Array[String] = []
var event_log: Array[Dictionary] = []  # single source of truth for day summary and end-screen hints
var last_day_report: Dictionary = {}

var _res: Dictionary = {}  # working data between day-end steps


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
	phase = PHASE_PLAYING
	game_over = false
	mission_won = false
	stars_earned = 0
	solar_penalty_amount = 0
	solar_penalty_days = 0
	pump_output_percent = 100
	pump_fault_days = 0
	oxygen_leak_amount = 0
	oxygen_leak_days = 0
	battery_cap = Rules.max_value("battery")
	comms_blocked_today = false
	comms_extra_delay = 0
	food_crates.clear()
	# The greenhouse was already running on Low before day 1, so its first harvests are on the way.
	var start_food := int(Rules.greenhouse_mode_data(greenhouse_mode).get("food", 0))
	for d in range(1, Rules.greenhouse_delay_days() + 1):
		food_crates[d] = start_food
	pending_messages.clear()
	forecast_storm_days.clear()
	pending_events.clear()
	storm_info = {}
	daily_log.clear()
	event_log.clear()
	last_day_report = {}
	_res = {}
	NasaData.reset_run()
	_add_log("Mission Day 1 started! Walk to a room and press E (or click it) to use it.")
	state_changed.emit()


func _log_event(entry: Dictionary) -> void:
	if not entry.has("day"):
		entry["day"] = day
	event_log.append(entry)


func has_logged_action(action_id: String, on_day: int = -1) -> bool:
	for entry in event_log:
		if String(entry.get("type", "")) == "action" and String(entry.get("action", "")) == action_id:
			if on_day < 0 or int(entry.get("day", -1)) == on_day:
				return true
	return false


func get_day_events(day_no: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in event_log:
		if int(entry.get("day", -1)) == day_no:
			out.append(entry)
	return out


func battery_max() -> int:
	return battery_cap


func _add_log(message: String) -> void:
	daily_log.append(message)


func storm_size_word(severity: int) -> String:
	return ["small", "medium", "big"][clampi(severity, 1, 3) - 1]


## Human-friendly word for how full a meter is (no numbers needed).
func meter_word(key: String) -> String:
	var val := int(get(key))
	var max_v := battery_max() if key == "battery" else Rules.max_value(key)
	if val <= 0:
		return "EMPTY!"
	var ratio := float(val) / float(maxi(1, max_v))
	if ratio >= 0.8:
		return "Full"
	if ratio >= 0.5:
		return "Good"
	if ratio >= 0.28:
		return "Okay"
	return "LOW!"


## Predicts whether a meter will go up, stay steady, or go down at end of day, so the player never has to calculate.
func meter_trend(key: String) -> String:
	match key:
		"battery":
			var dust := solar_penalty_amount if solar_penalty_days > 0 else 0
			var solar := maxi(0, Rules.power_solar() - dust)
			var cost := Rules.power_base_load() + _get_ls_cost(life_support_mode) \
				+ shield * Rules.shield_upkeep_per_level() \
				+ int(Rules.greenhouse_mode_data(greenhouse_mode).get("cost", 0))
			var net := solar - cost
			if net > 0:
				return "▲ Going up"
			if net < 0:
				return "▼ Going down"
			return "● Steady"
		"oxygen":
			var leak := oxygen_leak_amount if oxygen_leak_days > 0 else 0
			var net := _get_ls_o2(life_support_mode) - Rules.consumption_oxygen() - leak
			if net > 0:
				return "▲ Going up"
			if net < 0:
				return "▼ Going down"
			return "● Steady"
		"food":
			var arriving := int(food_crates.get(day, 0))
			var net := arriving - Rules.consumption_food()
			if net > 0:
				return "▲ Going up"
			if net < 0:
				return "▼ Going down"
			return "● Steady"
		"water":
			var net := Rules.water_recycle() - int(Rules.greenhouse_mode_data(greenhouse_mode).get("water", 0))
			if net > 0:
				return "▲ Going up"
			if net < 0:
				return "▼ Going down"
			return "● Steady"
		"health":
			if oxygen <= 0 or food <= 0:
				return "▼ Danger!"
			return "▲ Safe"
	return ""


## Visual dots for Actions Left today (e.g. "● ● ● ● ○ ○").
func ap_dots() -> String:
	var max_ap := Rules.ap_per_day()
	var dots: Array[String] = []
	for i in range(max_ap):
		dots.append("●" if i < ap else "○")
	return " ".join(dots)


## One-sentence helper coach that tells the player what to do next without any math.
func coach_hint() -> String:
	if phase == PHASE_STORM:
		return "🚨 SOLAR STORM! Click the purple Radiation Shelter (bottom middle) and press HIDE IN SHELTER!"
	if oxygen < 35 or meter_trend("oxygen") == "▼ Going down":
		return "💡 Coach Tip: Oxygen is dropping! Click Life Support (top right) and set it to Normal or High."
	if food < 25 and not has_logged_action("resupply") and day <= int(Rules.comms_data().get("resupply", {}).get("send_by_day", 6)):
		return "💡 Coach Tip: Food is getting low! Visit the Communications Room (bottom right) to call a Food Supply Rocket."
	if day in [2, 6, 8] and not has_logged_action("forecast", day) and ap >= 1 and not comms_blocked_today:
		return "💡 Coach Tip: Visit the Communications Room (bottom right) and Ask Earth for a Storm Forecast!"
	if shield < Rules.max_value("shield") and ap >= 2 and battery >= 30:
		return "💡 Coach Tip: You have spare energy! Visit the purple Radiation Shelter to Upgrade your Shield."
	if science < int(Rules.win_data().get("three_stars_science", 30)) and ap >= 2 and battery >= 40:
		return "💡 Coach Tip: Want 3 Stars? Visit the yellow Power Station to Do a Science Experiment!"
	if ap == 0:
		return "✅ You used all your Actions for today! Click 'Next Day >>' at the top right."
	return "✅ All systems look healthy! Explore the 5 rooms or click 'Next Day >>' when you are ready."


# ---------------------------------------------------------------- actions

func get_action_cost(action_id: String, param: Variant = null) -> Dictionary:
	var normalized := _normalize_action(action_id, param)
	var base_id: String = normalized["id"]
	var spec: Dictionary = Rules.action_data(base_id)
	return {"id": base_id, "param": normalized["param"], "ap": int(spec.get("ap", 0)),
		"power": int(spec.get("power", 0)), "spec": spec}


func _normalize_action(action_id: String, param: Variant = null) -> Dictionary:
	if action_id.begins_with("set_life_support_"):
		return {"id": "set_life_support", "param": action_id.trim_prefix("set_life_support_")}
	if action_id.begins_with("set_greenhouse_"):
		return {"id": "set_greenhouse", "param": action_id.trim_prefix("set_greenhouse_")}
	if action_id.begins_with("resupply_"):
		return {"id": "resupply", "param": action_id.trim_prefix("resupply_")}
	return {"id": action_id, "param": param}


func can_try_action(action_id: String, param: Variant = null) -> Dictionary:
	if game_over:
		return {"ok": false, "reason": "The mission has ended."}
	if phase != PHASE_PLAYING:
		return {"ok": false, "reason": "A solar storm is happening!"}

	var info := get_action_cost(action_id, param)
	var base_id: String = info["id"]
	var target_param: Variant = info["param"]
	var spec: Dictionary = info["spec"]
	if spec.is_empty():
		return {"ok": false, "reason": "Unknown action: " + action_id}

	var missing: Array[String] = []
	if ap < int(info["ap"]):
		missing.append("not enough Actions left today")
	if battery < int(info["power"]):
		missing.append("Battery is too low")
	if not missing.is_empty():
		return {"ok": false, "reason": " and ".join(missing)}

	match base_id:
		"set_life_support":
			var mode_str := String(target_param if target_param != null else "")
			if mode_str not in ["eco", "normal", "high"]:
				return {"ok": false, "reason": "Choose Eco, Normal, or High."}
			if life_support_mode == mode_str:
				return {"ok": false, "reason": "already on %s" % mode_str.capitalize()}
		"set_greenhouse":
			var gh_str := String(target_param if target_param != null else "")
			if gh_str not in ["off", "low", "high"]:
				return {"ok": false, "reason": "Choose Off, Low, or High."}
			if greenhouse_mode == gh_str:
				return {"ok": false, "reason": "already on %s" % gh_str.capitalize()}
		"upgrade_shield":
			if shield >= Rules.max_value("shield"):
				return {"ok": false, "reason": "Shield is already at the top level"}
		"forecast", "advice", "resupply":
			if comms_blocked_today:
				return {"ok": false, "reason": "radio blackout today"}
			if base_id == "resupply":
				var send_by := int(spec.get("send_by_day", 0))
				if day > send_by:
					return {"ok": false, "reason": "must be ordered by Day %d" % send_by}
				if not spec.get("options", {}).has(String(target_param if target_param != null else "")):
					return {"ok": false, "reason": "Choose oxygen, food, or water."}
	return {"ok": true, "reason": "Ready"}


func try_action(action_id: String, param: Variant = null) -> bool:
	var check := can_try_action(action_id, param)
	if not check.get("ok", false):
		_add_log("Cannot do that: " + String(check.get("reason", "")))
		state_changed.emit()
		return false

	var info := get_action_cost(action_id, param)
	var base_id: String = info["id"]
	var target_param: Variant = info["param"]
	var ap_cost: int = info["ap"]
	var power_cost: int = info["power"]
	var spec: Dictionary = info["spec"]

	ap -= ap_cost
	battery = clampi(battery - power_cost, 0, battery_max())
	var delay := int(Rules.comms_data().get("delay_days", 0)) + comms_extra_delay

	var log_text := ""
	match base_id:
		"experiment":
			var gain := int(spec.get("science", 0))
			science += gain
			log_text = "Experiment done! +%d Science." % gain
		"set_life_support":
			life_support_mode = String(target_param)
			log_text = "Life Support is now on %s." % life_support_mode.capitalize()
		"emergency_oxygen":
			var o2_gain := int(spec.get("oxygen", 0))
			oxygen = clampi(oxygen + o2_gain, 0, Rules.max_value("oxygen"))
			log_text = "Emergency oxygen used! +%d Oxygen." % o2_gain
		"set_greenhouse":
			greenhouse_mode = String(target_param)
			log_text = "Greenhouse is now %s." % greenhouse_mode.capitalize()
		"upgrade_shield":
			shield = clampi(shield + 1, 0, Rules.max_value("shield"))
			effective_shield_today = shield
			log_text = "Shield upgraded to level %d!" % shield
		"repair_pump":
			if pump_fault_days > 0:
				pump_fault_days = 0
				pump_output_percent = 100
				log_text = "Pump fixed! The Greenhouse works at full power again."
			else:
				log_text = "The pump was checked. It works fine."
		"repair_panel":
			if solar_penalty_days > 0:
				solar_penalty_days = 0
				solar_penalty_amount = 0
				log_text = "Solar panels cleaned! They collect full sunlight again."
			else:
				log_text = "The panels were checked. They are clean."
		"forecast":
			pending_messages.append({"deliver_day": day + delay, "type": "forecast"})
			log_text = "Forecast requested. It arrives on Day %d (messages take time)." % (day + delay)
		"advice":
			pending_messages.append({"deliver_day": day + delay, "type": "advice"})
			log_text = "You asked Mission Control for advice. The answer arrives on Day %d." % (day + delay)
		"resupply":
			var res_type := String(target_param)
			var amount := int(spec.get("options", {}).get(res_type, 0))
			var arrival := day + int(spec.get("delay", 0)) + comms_extra_delay
			pending_messages.append({"deliver_day": arrival, "type": "resupply", "resource": res_type, "amount": amount})
			log_text = "Resupply ordered: +%d %s on Day %d." % [amount, res_type.capitalize(), arrival]
	_add_log(log_text)
	_log_event({
		"day": day, "type": "action", "action": base_id, "param": target_param,
		"ap": ap_cost, "power": power_cost, "text": log_text,
	})
	state_changed.emit()
	return true


## Answer a daily event from events.json. Returns {"ok": bool, "reason": String}.
func can_choose_event(event_id: String, choice_id: String) -> Dictionary:
	var choice := EventManager.get_choice(event_id, choice_id)
	if choice.is_empty():
		return {"ok": false, "reason": "Unknown choice"}
	var ap_cost := int(choice.get("ap", 0))
	var power_cost := int(choice.get("power", 0))
	if ap < ap_cost:
		return {"ok": false, "reason": "needs %d AP" % ap_cost}
	if battery < power_cost:
		return {"ok": false, "reason": "needs %d power" % power_cost}
	return {"ok": true, "reason": ""}


func choose_event(event_id: String, choice_id: String) -> bool:
	if not can_choose_event(event_id, choice_id).get("ok", false):
		return false
	var choice := EventManager.get_choice(event_id, choice_id)
	var fx: Dictionary = choice.get("effects", {})
	ap -= int(choice.get("ap", 0))
	battery = clampi(battery - int(choice.get("power", 0)), 0, battery_max())

	if fx.has("science"):
		science += int(fx["science"])
	if fx.has("oxygen"):
		oxygen = clampi(oxygen + int(fx["oxygen"]), 0, Rules.max_value("oxygen"))
	if fx.has("solar_penalty"):
		solar_penalty_amount = int(fx["solar_penalty"].get("amount", 0))
		solar_penalty_days = int(fx["solar_penalty"].get("days", 0))
	if fx.get("clear_solar_penalty", false):
		solar_penalty_amount = 0
		solar_penalty_days = 0
	if fx.has("pump_fault"):
		pump_output_percent = int(fx["pump_fault"].get("output_percent", 100))
		pump_fault_days = int(fx["pump_fault"].get("days", 0))
	if fx.get("clear_pump_fault", false):
		pump_output_percent = 100
		pump_fault_days = 0
	if fx.has("set_greenhouse"):
		greenhouse_mode = String(fx["set_greenhouse"])
	if fx.has("oxygen_leak"):
		oxygen_leak_amount = int(fx["oxygen_leak"].get("amount", 0))
		oxygen_leak_days = int(fx["oxygen_leak"].get("days", 0))
	if fx.has("battery_max"):
		battery_cap = mini(battery_cap, int(fx["battery_max"]))
		battery = mini(battery, battery_cap)
	if fx.get("comms_blocked_today", false):
		comms_blocked_today = true
	if fx.has("comms_extra_delay"):
		comms_extra_delay = int(fx["comms_extra_delay"])
	if fx.has("reply"):
		var delay := int(Rules.comms_data().get("delay_days", 0)) + comms_extra_delay
		pending_messages.append({"deliver_day": day + delay, "type": "reply", "text": String(fx["reply"])})

	var ev_data := EventManager.get_event(event_id)
	var choice_text := "%s: %s." % [ev_data.get("title", event_id), choice.get("label", choice_id)]
	_add_log(choice_text)
	_log_event({
		"day": day, "type": "event_choice", "event_id": event_id, "choice_id": choice_id,
		"title": String(ev_data.get("title", event_id)), "label": String(choice.get("label", choice_id)),
		"effect": String(choice.get("effect", "")), "text": choice_text,
	})
	state_changed.emit()
	return true


# ------------------------------------------------------- day-end resolution

## Runs day-end steps 1-4. If a storm is scheduled, the storm phase starts and the day
## finishes later in resolve_storm(). Otherwise the whole day resolves here.
func end_day(advance_to_next_day: bool = true) -> Dictionary:
	if game_over or phase != PHASE_PLAYING:
		return last_day_report
	_resolve_resources(advance_to_next_day)
	var storm := EventManager.storm_for_day(day)
	if storm.is_empty():
		return _finish_day()
	var warned: bool = bool(storm.get("warned", false)) or forecast_storm_days.has(day)
	var severity := int(storm.get("severity", 1))
	var cfg := Rules.storm_data()
	storm_info = {
		"event_id": String(storm.get("id", "")), "day": day, "severity": severity, "warned": warned,
		"seconds": float(cfg.get("timer_warned" if warned else "timer_surprise", 0)),
		"record": NasaData.storm_record(String(storm.get("id", ""))),
	}
	phase = PHASE_STORM
	storm_occurred_today = true
	_add_log("A %s solar storm is coming!" % storm_size_word(severity))
	storm_started.emit(storm_info)
	state_changed.emit()
	return {}


func _resolve_resources(advance: bool) -> void:
	var before := {}
	for key in METER_KEYS:
		before[key] = get(key)
	var notes: Array[String] = []
	var cuts: Array[String] = []
	var lines := {"battery": [], "oxygen": [], "food": [], "water": [], "health": []}
	var eff_ls := life_support_mode
	var eff_gh := greenhouse_mode
	var eff_shield := shield

	# If water cannot cover today's greenhouse, it drops one level first and the player is told.
	var needed_water := int(Rules.greenhouse_mode_data(eff_gh).get("water", 0))
	if water < needed_water and eff_gh != "off":
		eff_gh = _drop_greenhouse_level(eff_gh)
		greenhouse_mode = eff_gh
		var msg := "Water was too low, so the Greenhouse went down to %s." % eff_gh.capitalize()
		cuts.append(msg)
		notes.append(msg)
		_log_event({"day": day, "type": "water_cut", "mode": eff_gh, "text": msg})

	# STEP 1: POWER. Pay in this order: base load, Life Support, shield upkeep, Greenhouse.
	var dust := solar_penalty_amount if solar_penalty_days > 0 else 0
	var solar := maxi(0, Rules.power_solar() - dust)
	var available := battery + solar
	var base_cost := Rules.power_base_load()
	var ls_cost := _get_ls_cost(eff_ls)
	var shield_cost := eff_shield * Rules.shield_upkeep_per_level()
	var gh_cost := int(Rules.greenhouse_mode_data(eff_gh).get("cost", 0))
	var total := base_cost + ls_cost + shield_cost + gh_cost

	if available < total:
		for cut_step in Rules.shortage_order():
			if available >= total:
				break
			var msg := ""
			match String(cut_step):
				"greenhouse":
					if eff_gh != "off":
						eff_gh = "off"
						gh_cost = 0
						msg = "Not enough power, so the base turned the Greenhouse off today."
				"life_support_eco":
					if eff_ls != "eco" and eff_ls != "off":
						eff_ls = "eco"
						ls_cost = _get_ls_cost("eco")
						msg = "Still not enough power, so Life Support dropped to Eco today."
				"shield_upkeep":
					if eff_shield > 0:
						eff_shield = 0
						shield_cost = 0
						msg = "Power was very low, so the Shield was switched off today (level 0 for storms)."
				"life_support_off":
					if eff_ls != "off":
						eff_ls = "off"
						ls_cost = 0
						msg = "Power ran out! Life Support was switched off today."
			if msg != "":
				cuts.append(msg)
				notes.append(msg)
				_log_event({"day": day, "type": "power_cut", "step": String(cut_step), "text": msg})
			total = base_cost + ls_cost + shield_cost + gh_cost

	effective_shield_today = eff_shield
	battery = clampi(available - total, 0, battery_max())
	lines["battery"].append("Solar panels: +%d%s" % [solar, " (dust is blocking %d)" % dust if dust > 0 else ""])
	lines["battery"].append("Base machines: -%d" % base_cost)
	if ls_cost > 0:
		lines["battery"].append("Life Support (%s): -%d" % [eff_ls.capitalize(), ls_cost])
	if shield_cost > 0:
		lines["battery"].append("Shield upkeep: -%d" % shield_cost)
	if gh_cost > 0:
		lines["battery"].append("Greenhouse (%s): -%d" % [eff_gh.capitalize(), gh_cost])

	# STEP 2: OXYGEN
	var ls_o2 := _get_ls_o2(eff_ls)
	var leak := oxygen_leak_amount if oxygen_leak_days > 0 else 0
	oxygen = clampi(oxygen + ls_o2 - Rules.consumption_oxygen() - leak, 0, Rules.max_value("oxygen"))
	lines["oxygen"].append("Life Support made: +%d" % ls_o2)
	lines["oxygen"].append("The crew breathed: -%d" % Rules.consumption_oxygen())
	if leak > 0:
		lines["oxygen"].append("Air leaking out: -%d" % leak)

	# STEP 3: FOOD (add harvests that arrive today, then subtract meals)
	var arriving := int(food_crates.get(day, 0))
	food_crates.erase(day)
	var gh_food := int(Rules.greenhouse_mode_data(eff_gh).get("food", 0))
	if pump_fault_days > 0:
		gh_food = int(floor(gh_food * pump_output_percent / 100.0))
	var crate_day := day + Rules.greenhouse_delay_days()
	if gh_food > 0:
		food_crates[crate_day] = int(food_crates.get(crate_day, 0)) + gh_food
	food = clampi(food + arriving - Rules.consumption_food(), 0, Rules.max_value("food"))
	if arriving > 0:
		lines["food"].append("Greenhouse harvest arrived: +%d" % arriving)
	lines["food"].append("Meals eaten: -%d" % Rules.consumption_food())

	# STEP 4: WATER
	var gh_water := int(Rules.greenhouse_mode_data(eff_gh).get("water", 0))
	water = clampi(water - gh_water + Rules.water_recycle(), 0, Rules.max_value("water"))
	if gh_water > 0:
		lines["water"].append("Greenhouse used: -%d" % gh_water)
	lines["water"].append("Water recycled: +%d" % Rules.water_recycle())
	var next_needed := int(Rules.greenhouse_mode_data(greenhouse_mode).get("water", 0))
	if water < next_needed and greenhouse_mode != "off":
		greenhouse_mode = _drop_greenhouse_level(greenhouse_mode)
		var water_msg := "Water is getting low, so the Greenhouse went down to %s." % greenhouse_mode.capitalize()
		cuts.append(water_msg)
		notes.append(water_msg)
		_log_event({"day": day, "type": "water_cut", "mode": greenhouse_mode, "text": water_msg})

	_res = {
		"before": before, "notes": notes, "cuts": cuts, "lines": lines, "advance": advance,
		"crate_day": crate_day, "crate_amount": gh_food, "storm": {}, "eff_ls": eff_ls, "eff_gh": eff_gh,
	}


## Storm phase result. reached_shelter = the player started the lockdown in time.
func resolve_storm(reached_shelter: bool) -> Dictionary:
	if phase != PHASE_STORM:
		return last_day_report
	var cfg := Rules.storm_data()
	var severity := int(storm_info.get("severity", 1))
	var base: int = int(cfg.get("base_damage", [0, 0, 0])[severity - 1])
	var factor := 1.0
	var lockdown := false
	var low_battery := false
	var notes: Array[String] = _res["notes"]
	var storm_note := ""

	if reached_shelter:
		var cost := int(cfg.get("lockdown_power", 0))
		if battery >= cost:
			battery -= cost
			factor = float(cfg.get("lockdown_factor", 1.0))
			lockdown = true
			_res["lines"]["battery"].append("Lockdown: -%d" % cost)
			storm_note = "Lockdown worked! The crew was safe in the shelter and took half the damage."
			notes.append(storm_note)
		else:
			battery = 0
			factor = float(cfg.get("lockdown_low_power_factor", 1.0))
			low_battery = true
			_res["lines"]["battery"].append("Lockdown used all the power left")
			storm_note = "The battery was too low for a full lockdown, so the shelter only helped a little."
			notes.append(storm_note)
		# Lockdown pauses the greenhouse for the day: today's harvest is not made.
		var crate_day: int = _res["crate_day"]
		var lost: int = _res["crate_amount"]
		if lost > 0 and food_crates.has(crate_day):
			food_crates[crate_day] = maxi(0, int(food_crates[crate_day]) - lost)
			notes.append("The Greenhouse was paused, so no harvest was made today.")
	else:
		storm_note = "The crew did not reach the shelter in time, so they took full damage."
		notes.append(storm_note)

	# Damage = ceil(base x (1 - shield_reduction x shield) x lockdown factor)
	var raw := base * (1.0 - float(cfg.get("shield_reduction", 0.0)) * effective_shield_today) * factor
	var damage := ceili(snappedf(raw, 0.000001))
	_res["storm"] = {
		"day": day, "type": "storm", "severity": severity, "warned": bool(storm_info.get("warned", false)),
		"reached_shelter": reached_shelter, "lockdown": lockdown, "low_battery": low_battery,
		"shield": effective_shield_today, "damage": damage, "event_id": storm_info.get("event_id", ""),
		"text": storm_note,
	}
	_log_event(_res["storm"].duplicate())
	phase = PHASE_PLAYING
	return _finish_day()


func _finish_day() -> Dictionary:
	var resolved_day := day
	var notes: Array[String] = _res["notes"]
	var lines: Dictionary = _res["lines"]
	var before: Dictionary = _res["before"]
	var storm: Dictionary = _res["storm"]

	# STEP 6: HEALTH (penalties; otherwise +heal if there was no storm)
	var penalties := Rules.penalties_data()
	var had_penalty := false
	if oxygen <= 0:
		var o2_pen := int(penalties.get("oxygen_zero", 0))
		health -= o2_pen
		had_penalty = true
		lines["health"].append("No oxygen: -%d" % o2_pen)
		var o2_msg := "The crew ran out of oxygen! Health dropped."
		notes.append(o2_msg)
		_log_event({"day": resolved_day, "type": "penalty", "resource": "oxygen", "damage": o2_pen, "text": o2_msg})
	if food <= 0:
		var food_pen := int(penalties.get("food_zero", 0))
		health -= food_pen
		had_penalty = true
		lines["health"].append("No food: -%d" % food_pen)
		var food_msg := "The crew ran out of food! Health dropped."
		notes.append(food_msg)
		_log_event({"day": resolved_day, "type": "penalty", "resource": "food", "damage": food_pen, "text": food_msg})
	if not storm.is_empty():
		health -= int(storm["damage"])
		lines["health"].append("Solar storm radiation: -%d" % int(storm["damage"]))
	elif not had_penalty:
		var heal := int(penalties.get("daily_heal", 0))
		health += heal
		if heal > 0:
			lines["health"].append("A calm day, the crew rested: +%d" % heal)
	health = clampi(health, 0, Rules.max_value("health"))

	# Win or loss
	if health <= 0:
		game_over = true
		mission_won = false
		stars_earned = 0
		notes.append("Crew health reached 0. The mission ended. Let's try again!")
	elif resolved_day >= Rules.mission_days():
		game_over = true
		var win_spec := Rules.win_data()
		if health >= int(win_spec.get("min_health", 0)):
			mission_won = true
			stars_earned = 1
			if health >= int(win_spec.get("two_stars_health", 0)):
				stars_earned = 2
				if science >= int(win_spec.get("three_stars_science", 0)):
					stars_earned = 3
		else:
			mission_won = false
			stars_earned = 0

	# End-of-day countdowns for problems caused by events
	if solar_penalty_days > 0:
		solar_penalty_days -= 1
		if solar_penalty_days == 0:
			solar_penalty_amount = 0
	if pump_fault_days > 0:
		pump_fault_days -= 1
		if pump_fault_days == 0:
			pump_output_percent = 100
	if oxygen_leak_days > 0:
		oxygen_leak_days -= 1
		if oxygen_leak_days == 0:
			oxygen_leak_amount = 0

	var meters: Array = []
	for key in METER_KEYS:
		meters.append({"key": key, "label": String(key).capitalize(), "before": int(before[key]),
			"after": int(get(key)), "lines": lines[key].duplicate()})

	# STEP 7: NEXT DAY (refill AP, deliver messages, queue events)
	var messages: Array[String] = []
	if bool(_res["advance"]) and not game_over:
		day += 1
		ap = Rules.ap_per_day()
		storm_occurred_today = false
		comms_blocked_today = false
		comms_extra_delay = 0
		effective_shield_today = shield
		_deliver_messages(messages, lines)
		pending_events = EventManager.events_for_day(day)

	last_day_report = {
		"day": resolved_day, "type": "day_end",
		"resolved_day": resolved_day, "battery": battery, "oxygen": oxygen, "food": food, "water": water,
		"health": health, "shield": shield, "effective_shield_today": effective_shield_today,
		"science": science, "cuts": _res["cuts"], "notes": notes, "messages": messages,
		"meters": meters, "storm": storm, "game_over": game_over, "won": mission_won, "stars": stars_earned,
	}
	_log_event(last_day_report.duplicate(true))
	_add_log("Day %d done: Battery %d, Oxygen %d, Food %d, Water %d, Health %d." % [
		resolved_day, battery, oxygen, food, water, health])
	for cut_text in _res["cuts"]:
		_add_log(cut_text)
	_res = {}
	day_ended.emit(last_day_report)
	state_changed.emit()
	return last_day_report


func _deliver_messages(messages: Array[String], lines: Dictionary) -> void:
	var remaining: Array[Dictionary] = []
	var span := int(Rules.comms_data().get("delay_days", 0))
	for msg in pending_messages:
		if int(msg.get("deliver_day", 0)) > day:
			remaining.append(msg)
			continue
		var text := ""
		var mtype := String(msg.get("type", ""))
		match mtype:
			"forecast":
				# A forecast covers storms from the day it arrives until `delay_days` days later.
				var storms := EventManager.storms_between(day, day + span)
				var parts: Array[String] = []
				for s in storms:
					var d := int(s.get("day", 0))
					if not forecast_storm_days.has(d):
						forecast_storm_days.append(d)
					parts.append("a %s storm on Day %d" % [storm_size_word(int(s.get("severity", 1))), d])
				if parts.is_empty():
					text = "Forecast from Earth: no storms are expected soon."
				else:
					text = "Forecast from Earth: " + " and ".join(parts) + "."
			"advice":
				text = _advice_tip()
			"reply":
				text = String(msg.get("text", "A message from Earth arrived."))
			"resupply":
				var res := String(msg.get("resource", ""))
				var amt := int(msg.get("amount", 0))
				match res:
					"oxygen":
						oxygen = clampi(oxygen + amt, 0, Rules.max_value("oxygen"))
					"food":
						food = clampi(food + amt, 0, Rules.max_value("food"))
					"water":
						water = clampi(water + amt, 0, Rules.max_value("water"))
				if lines.has(res):
					lines[res].append("Supply pod from Earth: +%d" % amt)
				text = "A supply pod landed! +%d %s." % [amt, res.capitalize()]
		messages.append(text)
		_add_log(text)
		_log_event({"day": day, "type": "message_delivered", "msg_type": mtype, "text": text})
	pending_messages = remaining


func _advice_tip() -> String:
	if shield < Rules.max_value("shield"):
		return "Mission Control says: a higher Shield level means less damage from solar storms."
	if battery < int(Rules.storm_data().get("lockdown_power", 0)) * 3:
		return "Mission Control says: keep some battery power for the shelter lockdown."
	return "Mission Control says: great work! Visit all five rooms every day."


func _get_ls_cost(mode: String) -> int:
	return 0 if mode == "off" else int(Rules.life_support_mode_data(mode).get("cost", 0))


func _get_ls_o2(mode: String) -> int:
	return 0 if mode == "off" else int(Rules.life_support_mode_data(mode).get("o2", 0))


func _drop_greenhouse_level(mode: String) -> String:
	return "low" if mode == "high" else "off"


# ------------------------------------------------------------------ test

## Reproduces the day-5 worked example in docs/game_mechanics.md.
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
	life_support_mode = "normal"
	greenhouse_mode = "low"
	# The harvest made on day 3 (Greenhouse Low) arrives on day 5.
	food_crates.clear()
	food_crates[5] = int(Rules.greenhouse_mode_data("low").get("food", 0))

	var ok_pump := try_action("repair_pump")
	var ok_forecast := try_action("forecast")
	var ok_experiment := try_action("experiment")
	var after_actions := battery
	var report := end_day()

	var passed := ok_pump and ok_forecast and ok_experiment and after_actions == 28 \
		and battery == 32 and oxygen == 70 and food == 27 and water == 25 and health == 100
	var result := {
		"passed": passed, "battery_after_actions": after_actions, "battery": battery, "oxygen": oxygen,
		"food": food, "water": water, "health": health, "report": report,
		"expected": {"battery_after_actions": 28, "battery": 32, "oxygen": 70, "food": 27, "water": 25, "health": 100},
	}
	var line := "[Day-5 test: %s] after actions battery=%d (expected 28) | end of day: battery=%d (32), oxygen=%d (70), food=%d (27), water=%d (25), health=%d (100)" % [
		"PASS" if passed else "FAIL", after_actions, battery, oxygen, food, water, health]
	print(line)
	_add_log(line)
	state_changed.emit()
	return result
