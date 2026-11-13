extends Node
## Single source of truth loader for data/rules.json.
## No balance numbers may be hardcoded in any script.

const RULES_PATH := "res://data/rules.json"

var data: Dictionary = {}


func _init() -> void:
	load_rules()


func _ready() -> void:
	if data.is_empty():
		load_rules()


func load_rules() -> void:
	if not FileAccess.file_exists(RULES_PATH):
		push_error("Rules file not found at: " + RULES_PATH)
		return
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open rules file: " + RULES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
	else:
		push_error("Failed to parse JSON in: " + RULES_PATH)


func mission_days() -> int:
	return int(data.get("mission_days", 0))


func ap_per_day() -> int:
	return int(data.get("ap_per_day", 0))


func start_value(key: String) -> int:
	var start_dict: Dictionary = data.get("start", {})
	return int(start_dict.get(key, 0))


func max_value(key: String) -> int:
	var max_dict: Dictionary = data.get("max", {})
	return int(max_dict.get(key, 0))


func power_solar() -> int:
	var power_dict: Dictionary = data.get("power", {})
	return int(power_dict.get("solar", 0))


func power_base_load() -> int:
	var power_dict: Dictionary = data.get("power", {})
	return int(power_dict.get("base_load", 0))


func shield_upkeep_per_level() -> int:
	var power_dict: Dictionary = data.get("power", {})
	return int(power_dict.get("shield_upkeep_per_level", 0))


func life_support_mode_data(mode: String) -> Dictionary:
	var ls_dict: Dictionary = data.get("life_support", {})
	return ls_dict.get(mode, {"cost": 0, "o2": 0})


func greenhouse_mode_data(mode: String) -> Dictionary:
	var gh_dict: Dictionary = data.get("greenhouse", {})
	return gh_dict.get(mode, {"cost": 0, "water": 0, "food": 0})


func greenhouse_delay_days() -> int:
	var gh_dict: Dictionary = data.get("greenhouse", {})
	return int(gh_dict.get("delay_days", 0))


func consumption_oxygen() -> int:
	var cons_dict: Dictionary = data.get("consumption", {})
	return int(cons_dict.get("oxygen", 0))


func consumption_food() -> int:
	var cons_dict: Dictionary = data.get("consumption", {})
	return int(cons_dict.get("food", 0))


func water_recycle() -> int:
	return int(data.get("water_recycle", 0))


func shortage_order() -> Array:
	return data.get("shortage_order", [])


func storm_data() -> Dictionary:
	return data.get("storm", {})


func comms_data() -> Dictionary:
	return data.get("comms", {})


func action_data(action_id: String) -> Dictionary:
	var actions_dict: Dictionary = data.get("actions", {})
	if actions_dict.has(action_id):
		return actions_dict[action_id]
	var comms_dict: Dictionary = data.get("comms", {})
	if comms_dict.has(action_id) and typeof(comms_dict[action_id]) == TYPE_DICTIONARY:
		return comms_dict[action_id]
	return {}


func penalties_data() -> Dictionary:
	return data.get("penalties", {})


func win_data() -> Dictionary:
	return data.get("win", {})

