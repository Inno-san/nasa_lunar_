extends Node
## Loads the saved (cached) NASA data from data/. The game never calls NASA live.
## If a file is missing or empty, small built-in records are used so the game cannot crash.

const SAVED_LABEL := "Saved NASA data"
const DONKI_PATH := "res://data/donki_cached.json"
const OSDR_PATH := "res://data/osdr_facts.json"
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# Built-in copies of a few real records, used only when the JSON files cannot be read.
const FALLBACK_STORMS: Array = [
	{"game_event": "storm_1", "severity": 1, "donki_id": "2024-05-07T05:58:00-FLR-001", "type": "Solar flare",
		"flare_class": "M5.1", "peak_time": "2024-05-07T06:16Z",
		"link": "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30498/-1",
		"kid_text": "A medium-strong solar flare. A flare is a sudden flash of energy from the Sun."},
	{"game_event": "storm_2", "severity": 2, "donki_id": "2024-05-10T06:27:00-FLR-001", "type": "Solar flare",
		"flare_class": "X3.9", "peak_time": "2024-05-10T06:54Z",
		"link": "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30666/-1",
		"kid_text": "A very strong solar flare. Bursts like this can send extra radiation toward space."},
	{"game_event": "storm_3", "severity": 3, "donki_id": "2024-05-14T16:46:00-FLR-001", "type": "Solar flare",
		"flare_class": "X8.7", "peak_time": "2024-05-14T16:51Z",
		"link": "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30849/-1",
		"kid_text": "One of the strongest flares of that month. Astronauts would shelter from storms like this."},
]
const FALLBACK_FACTS: Array = [
	{"id": "OSD-804", "topic": "Bones", "studied": "Mice", "date": "2025-01-29",
		"link": "https://osdr.nasa.gov/bio/repo/data/studies/OSD-804",
		"text": "Mice lived on the space station for 37 days. Some of their leg bones got weaker. In space, bones carry less weight."},
	{"id": "OSD-575", "topic": "Astronaut health", "studied": "Humans", "date": "2024-05-14",
		"link": "https://osdr.nasa.gov/bio/repo/data/studies/OSD-575",
		"text": "Four private astronauts flew for 3 days on Inspiration4. Scientists took blood samples before and after to see how bodies react to space."},
	{"id": "OSD-655", "topic": "Space food", "studied": "Plants", "date": "2025-12-22",
		"link": "https://osdr.nasa.gov/bio/repo/data/studies/OSD-655",
		"text": "Astronauts grew and harvested leafy greens on the space station. Scientists tested how light colour changes the plants."},
]

var storm_records: Array = []
var facts: Array = []

var _fact_order: Array = []
var _fact_cursor: int = 0
var facts_repeated: bool = false


func _init() -> void:
	load_all()
	reset_run()


func _ready() -> void:
	if storm_records.is_empty() or facts.is_empty():
		load_all()
		reset_run()


func load_all() -> void:
	storm_records = Rules.read_json_dict(DONKI_PATH).get("records", [])
	if storm_records.is_empty():
		storm_records = FALLBACK_STORMS.duplicate(true)

	facts = Rules.read_json_dict(OSDR_PATH).get("facts", [])
	if facts.is_empty():
		facts = FALLBACK_FACTS.duplicate(true)


## Call at the start of every new run so facts can be shown again.
func reset_run() -> void:
	_fact_order = range(facts.size())
	_fact_order.shuffle()
	_fact_cursor = 0
	facts_repeated = false


## Returns the next fact. No fact repeats within a run until all of them were shown.
func next_fact() -> Dictionary:
	if facts.is_empty():
		return {}
	if _fact_cursor >= _fact_order.size():
		_fact_order.shuffle()
		_fact_cursor = 0
		facts_repeated = true
	var fact: Dictionary = facts[_fact_order[_fact_cursor]]
	_fact_cursor += 1
	return fact


func storm_record(event_id: String) -> Dictionary:
	for rec in storm_records:
		if String(rec.get("game_event", "")) == event_id:
			return rec
	return {}


## "2024-05-07T06:16Z" or "2025-01-29" -> "7 May 2024"
func format_date(iso: String) -> String:
	var parts := iso.substr(0, 10).split("-")
	if parts.size() != 3:
		return iso
	var month := int(parts[1])
	if month < 1 or month > 12:
		return iso
	return "%d %s %s" % [int(parts[2]), MONTHS[month - 1], parts[0]]


func storm_title(record: Dictionary) -> String:
	var kind := String(record.get("type", "Solar flare"))
	var cls := String(record.get("flare_class", ""))
	return ("%s (class %s)" % [kind, cls]) if cls != "" else kind


func fact_source_line(fact: Dictionary) -> String:
	return "NASA OSDR study %s, released %s. Studied: %s." % [
		fact.get("id", "?"), format_date(String(fact.get("date", ""))), fact.get("studied", "?")]

