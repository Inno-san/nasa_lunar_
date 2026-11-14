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
	data = read_json_dict(RULES_PATH)
	if data.is_empty():
		push_error("Failed to load JSON in: " + RULES_PATH)


static func read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func mission_days() -> int:
	return int(data.get("mission_days", 0))


func ap_per_day() -> int:
	return int(data.get("ap_per_day", 0))


func start_value(key: String) -> int:
	return int(data.get("start", {}).get(key, 0))


func max_value(key: String) -> int:
	return int(data.get("max", {}).get(key, 0))


func power_solar() -> int:
	return int(data.get("power", {}).get("solar", 0))


func power_base_load() -> int:
	return int(data.get("power", {}).get("base_load", 0))


func shield_upkeep_per_level() -> int:
	return int(data.get("power", {}).get("shield_upkeep_per_level", 0))


func life_support_mode_data(mode: String) -> Dictionary:
	return data.get("life_support", {}).get(mode, {"cost": 0, "o2": 0})


func greenhouse_mode_data(mode: String) -> Dictionary:
	return data.get("greenhouse", {}).get(mode, {"cost": 0, "water": 0, "food": 0})


func greenhouse_delay_days() -> int:
	return int(data.get("greenhouse", {}).get("delay_days", 0))


func consumption_oxygen() -> int:
	return int(data.get("consumption", {}).get("oxygen", 0))


func consumption_food() -> int:
	return int(data.get("consumption", {}).get("food", 0))


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

