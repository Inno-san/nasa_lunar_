class_name ReplayHints
extends RefCounted
## Builds the "What went wrong" list on the end screen directly from GameState.event_log.
## Every sentence is short and plain. Numbers come from Rules and events.json.

const MAX_HINTS := 6


static func build() -> Array[String]:
	var hints: Array[String] = []
	var delay := int(Rules.comms_data().get("delay_days", 0))

	var oxygen_zero_days: Array[int] = []
	var food_zero_days: Array[int] = []
	var forecast_days: Array[int] = []
	var resupply_days: Array[int] = []
	var storms: Array[Dictionary] = []
	var power_cut_days: Array[String] = []
	var ignored_events: Array[Dictionary] = []

	for entry in GameState.event_log:
		var etype := String(entry.get("type", ""))
		var d := int(entry.get("day", 0))
		match etype:
			"penalty":
				var res := String(entry.get("resource", ""))
				if res == "oxygen" and not oxygen_zero_days.has(d):
					oxygen_zero_days.append(d)
				elif res == "food" and not food_zero_days.has(d):
					food_zero_days.append(d)
			"action":
				var act := String(entry.get("action", ""))
				if act == "forecast" and not forecast_days.has(d):
					forecast_days.append(d)
				elif act == "resupply" and not resupply_days.has(d):
					resupply_days.append(d)
			"storm":
				storms.append(entry)
			"power_cut":
				var d_str := str(d)
				if not power_cut_days.has(d_str):
					power_cut_days.append(d_str)
			"event_choice":
				if String(entry.get("choice_id", "")) == "ignore":
					ignored_events.append(entry)

	if not GameState.mission_won and GameState.health <= 0:
		hints.append("The crew's health reached 0 on Day %d. Check the five meters before you end each day." % GameState.last_day_report.get("resolved_day", GameState.day))

	for day_no in oxygen_zero_days:
		hints.append("On Day %d the crew ran out of oxygen. Keep Life Support on Normal or High." % day_no)
		break
	for day_no in food_zero_days:
		hints.append("On Day %d the crew ran out of food. The Greenhouse takes %d days to make food, so start it early." % [day_no, Rules.greenhouse_delay_days()])
		break

	for storm in storms:
		var d := int(storm["day"])
		var sev := int(storm["severity"])
		if sev >= 2 and not bool(storm["warned"]):
			var send_by := d - delay
			if forecast_days.is_empty():
				hints.append("You skipped the forecast before the Day %d storm. A forecast takes %d days, so ask by Day %d." % [d, delay, send_by])
			else:
				hints.append("Your forecast was sent too late for the Day %d storm. It needed to be sent by Day %d." % [d, send_by])
		if not bool(storm["reached_shelter"]):
			hints.append("On Day %d you did not reach the Radiation Shelter in time. A lockdown cuts storm damage a lot." % d)
		elif bool(storm["low_battery"]):
			hints.append("The battery was too low for a full lockdown on Day %d. Keep at least %d power for storms." % [d, int(Rules.storm_data().get("lockdown_power", 0))])
		if int(storm["shield"]) < Rules.max_value("shield") and int(storm["damage"]) > 0:
			hints.append("Your shield was level %d in the Day %d storm. A higher shield level means less damage." % [storm["shield"], d])

	if not power_cut_days.is_empty():
		hints.append("Power ran short on Day %s, so the base switched things off. Check the power balance in the Power Station." % ", ".join(power_cut_days))

	for ev_entry in ignored_events:
		hints.append("You ignored \"%s\" on Day %d: %s." % [
			ev_entry.get("title", ev_entry.get("event_id", "")),
			int(ev_entry.get("day", 0)),
			ev_entry.get("effect", "it caused trouble"),
		])

	if GameState.mission_won:
		var win := Rules.win_data()
		if GameState.stars_earned < 2:
			hints.append("For 2 stars, finish with health %d or more. You finished with %d." % [win.get("two_stars_health", 0), GameState.health])
		elif GameState.stars_earned < 3:
			hints.append("For 3 stars you need %d Science. You had %d. Experiments give Science." % [win.get("three_stars_science", 0), GameState.science])
	elif resupply_days.is_empty() and (not oxygen_zero_days.is_empty() or not food_zero_days.is_empty()):
		var comms := Rules.comms_data()
		hints.append("You never ordered a resupply. Orders must be sent by Day %d." % int(comms.get("resupply", {}).get("send_by_day", 0)))

	if hints.size() > MAX_HINTS:
		hints.resize(MAX_HINTS)
	if hints.is_empty():
		hints.append("Great run! We found no big mistakes.")
	return hints
