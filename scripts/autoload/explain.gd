extends CanvasLayer
## Tap-to-explain help for the key words in the game (works with mouse, touch and keyboard).
## Use Explain.make_button("battery") to get a small "?" button next to any label.

const TERMS := {
	"solar_storm": {
		"title": "Solar storm",
		"text": "A solar storm is a burst of energy and tiny particles from the Sun. It can send extra radiation toward the Moon.",
	},
	"radiation": {
		"title": "Radiation",
		"text": "Radiation is invisible energy that can harm living things. Astronauts need protection from too much of it.",
	},
	"shielding": {
		"title": "Shielding",
		"text": "Shielding is a thick wall that blocks some radiation. A higher shield level means less storm damage.",
	},
	"oxygen": {
		"title": "Oxygen",
		"text": "Oxygen is the gas we breathe. In this game, Life Support makes it for the crew.",
	},
	"battery": {
		"title": "Battery",
		"text": "The battery stores power from the solar panels. Every machine in the base uses it. PU means Power Units.",
	},
	"greenhouse": {
		"title": "Greenhouse",
		"text": "A greenhouse is a room for growing plants. Plants give the crew fresh food, but they need water and power.",
	},
	"comm_delay": {
		"title": "Communication delay",
		"text": "Radio messages take time to travel between Earth and the Moon. In this game the wait is %d days, so plan ahead!",
	},
}

var _overlay: Control = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func term_text(term_id: String) -> String:
	var term: Dictionary = TERMS.get(term_id, {})
	var text := String(term.get("text", ""))
	if term_id == "comm_delay":
		text = text % int(Rules.comms_data().get("delay_days", 0))
	return text


func term_title(term_id: String) -> String:
	return String(TERMS.get(term_id, {}).get("title", term_id))


func make_button(term_id: String) -> Button:
	var btn := UiKit.button("?", UiKit.FONT_SMALL, Vector2(40, 40))
	btn.tooltip_text = "What is %s? Tap to find out." % term_title(term_id).to_lower()
	btn.pressed.connect(show_term.bind(term_id))
	return btn


func show_term(term_id: String) -> void:
	close()
	var parts := UiKit.make_overlay(560.0)
	_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(UiKit.label(term_title(term_id), UiKit.FONT_TITLE, UiKit.COLOR_WARN))
	box.add_child(UiKit.label(term_text(term_id), UiKit.FONT_BODY))
	var ok := UiKit.button("Got it!")
	ok.pressed.connect(close)
	box.add_child(ok)
	add_child(_overlay)
	ok.grab_focus()


func close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func is_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

