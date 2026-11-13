class_name EventPopup
extends Control
## Shows one daily event from events.json and lets the player pick a choice.

signal answered

var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_event(event: Dictionary) -> void:
	close()
	var parts := UiKit.make_overlay(720.0)
	_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(UiKit.label("Day %d: %s" % [int(event.get("day", 0)), event.get("title", "News")], UiKit.FONT_TITLE, UiKit.COLOR_WARN))
	box.add_child(UiKit.label(String(event.get("text", "")), UiKit.FONT_BODY))

	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		var ok := UiKit.button("OK")
		ok.pressed.connect(_finish)
		box.add_child(ok)
		add_child(_overlay)
		ok.grab_focus()
		return

	box.add_child(UiKit.label("What do you do?   You have %d AP and %d power." % [GameState.ap, GameState.battery], UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
	var first_enabled: Button = null
	for c in choices:
		var check := GameState.can_choose_event(String(event["id"]), String(c["id"]))
		var cost := "%d AP, %d power" % [int(c.get("ap", 0)), int(c.get("power", 0))]
		var text := "%s   (%s)\n%s" % [c.get("label", c["id"]), cost, _describe(c.get("effects", {}))]
		if not bool(check["ok"]):
			text += "\nNot enough: " + String(check["reason"])
		var btn := UiKit.button(text, UiKit.FONT_BODY, Vector2(0, 72))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not bool(check["ok"])
		btn.pressed.connect(_choose.bind(String(event["id"]), String(c["id"])))
		box.add_child(btn)
		if first_enabled == null and not btn.disabled:
			first_enabled = btn
	add_child(_overlay)
	if first_enabled != null:
		first_enabled.grab_focus()


## Plain-language result of a choice, built from the numbers in events.json.
func _describe(fx: Dictionary) -> String:
	var parts: Array[String] = []
	if fx.has("science"):
		parts.append("+%d Science" % int(fx["science"]))
	if fx.has("oxygen"):
		parts.append("+%d oxygen now" % int(fx["oxygen"]))
	if fx.get("clear_solar_penalty", false):
		parts.append("panels stay clean")
	if fx.has("solar_penalty"):
		parts.append("dust blocks %d power a day for %d days" % [int(fx["solar_penalty"]["amount"]), int(fx["solar_penalty"]["days"])])
	if fx.get("clear_pump_fault", false):
		parts.append("the pump works again")
	if fx.has("pump_fault"):
		parts.append("Greenhouse food is only %d%% for %d days" % [int(fx["pump_fault"]["output_percent"]), int(fx["pump_fault"]["days"])])
	if fx.has("set_greenhouse"):
		parts.append("Greenhouse turns %s" % String(fx["set_greenhouse"]))
	if fx.has("oxygen_leak"):
		parts.append("air leaks: -%d oxygen a day for %d day(s)" % [int(fx["oxygen_leak"]["amount"]), int(fx["oxygen_leak"]["days"])])
	if fx.has("battery_max"):
		parts.append("battery can only hold %d" % int(fx["battery_max"]))
	if fx.get("comms_blocked_today", false):
		parts.append("no messages to Earth today")
	if fx.has("comms_extra_delay"):
		parts.append("replies take %d day longer" % int(fx["comms_extra_delay"]))
	if fx.has("reply"):
		parts.append("Earth replies (it takes time)")
	if parts.is_empty():
		return "Nothing changes."
	return "Result: " + ", ".join(parts) + "."


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

