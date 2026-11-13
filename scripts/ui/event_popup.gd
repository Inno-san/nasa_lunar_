class_name EventPopup
extends Control
## Shows one daily event from events.json with plain-language choices (no math or raw numbers).

signal answered

var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_event(event: Dictionary) -> void:
	close()
	var parts := UiKit.make_overlay(740.0)
	_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(UiKit.label("Day %d News: %s" % [int(event.get("day", 0)), event.get("title", "News")], UiKit.FONT_TITLE, UiKit.COLOR_WARN))
	box.add_child(UiKit.label(String(event.get("text", "")), UiKit.FONT_BODY))

	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		var ok := UiKit.button("Got it! ▶")
		ok.pressed.connect(_finish)
		box.add_child(ok)
		add_child(_overlay)
		ok.grab_focus()
		return

	box.add_child(UiKit.label("What would you like to do?   (Actions left today: %s)" % GameState.ap_dots(), UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
	var first_enabled: Button = null
	for c in choices:
		var check := GameState.can_choose_event(String(event["id"]), String(c["id"]))
		var text := "▶  %s\n    %s" % [c.get("label", c["id"]), _describe(c.get("effects", {}))]
		if not bool(check["ok"]):
			text = "%s\n    (Cannot pick right now: %s)" % [c.get("label", c["id"]), _friendly_reason(String(check["reason"]))]
		var btn := UiKit.button(text, UiKit.FONT_BODY, Vector2(0, 70))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not bool(check["ok"])
		btn.pressed.connect(_choose.bind(String(event["id"]), String(c["id"])))
		box.add_child(btn)
		if first_enabled == null and not btn.disabled:
			first_enabled = btn
	add_child(_overlay)
	if first_enabled != null:
		first_enabled.grab_focus()


func _friendly_reason(reason: String) -> String:
	if "AP" in reason:
		return "not enough Actions left today"
	if "power" in reason:
		return "Battery is too low"
	return reason


func _describe(fx: Dictionary) -> String:
	var parts: Array[String] = []
	if fx.has("science"):
		parts.append("gives a big Science boost toward 3 Stars!" if int(fx["science"]) >= 20 else "gives a Science boost")
	if fx.has("oxygen"):
		parts.append("adds fresh Oxygen right now")
	if fx.get("clear_solar_penalty", false):
		parts.append("keeps solar panels clean and strong")
	if fx.has("solar_penalty"):
		parts.append("dust blocks some sunlight for a few days")
	if fx.get("clear_pump_fault", false):
		parts.append("fixes the water pump so plants grow normally")
	if fx.has("pump_fault"):
		parts.append("Greenhouse grows less food for a few days")
	if fx.has("set_greenhouse"):
		parts.append("turns the Greenhouse %s" % String(fx["set_greenhouse"]))
	if fx.has("oxygen_leak"):
		parts.append("a little air leaks out today" if int(fx["oxygen_leak"].get("days", 1)) == 1 else "air keeps leaking for a few days")
	if fx.has("battery_max"):
		parts.append("the Battery holds slightly less power for the rest of the trip")
	if fx.get("comms_blocked_today", false):
		parts.append("waits until radio static clears tomorrow")
	if fx.has("comms_extra_delay"):
		parts.append("messages sent today take an extra day to arrive")
	if fx.has("reply"):
		parts.append("asks Earth for help (remember: replies take a couple of days!)")
	if parts.is_empty():
		return "Saves your energy for other tasks today."
	return "What happens: " + ", ".join(parts) + "."


func _choose(event_id: String, choice_id: String) -> void:
	if GameState.choose_event(event_id, choice_id):
		_finish()


func _finish() -> void:
	close()
	answered.emit()


func close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func is_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)
