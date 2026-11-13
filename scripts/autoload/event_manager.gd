extends Node
## Reads data/events.json: the 10-day schedule of daily events and storms.
## The numbers for each choice live in events.json; this script only looks them up.

const EVENTS_PATH := "res://data/events.json"

var events: Array = []


func _ready() -> void:
	load_events()


func load_events() -> void:
	events.clear()
	if not FileAccess.file_exists(EVENTS_PATH):
		push_error("Events file not found: " + EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.open(EVENTS_PATH, FileAccess.READ).get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		events = parsed.get("events", [])


## The storm planned for this day, or {} if none. Keys: id, severity, warned.
func storm_for_day(day: int) -> Dictionary:
	for e in events:
		if String(e.get("type", "")) == "storm" and int(e.get("day", 0)) == day:
			return e
	return {}


## Storms between two days (inclusive), used by the forecast message.
func storms_between(first_day: int, last_day: int) -> Array:
	var found: Array = []
	for e in events:
		if String(e.get("type", "")) == "storm":
			var d := int(e.get("day", 0))
			if d >= first_day and d <= last_day:
				found.append(e)
	return found


## Daily events the player must answer at the start of this day (in file order).
func events_for_day(day: int) -> Array:
	var found: Array = []
	for e in events:
		if int(e.get("day", 0)) == day and String(e.get("type", "")) != "storm":
			found.append(e)
	return found


func get_event(event_id: String) -> Dictionary:
	for e in events:
		if String(e.get("id", "")) == event_id:
			return e
	return {}


func get_choice(event_id: String, choice_id: String) -> Dictionary:
	for c in get_event(event_id).get("choices", []):
		if String(c.get("id", "")) == choice_id:
			return c
	return {}
