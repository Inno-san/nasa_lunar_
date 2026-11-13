class_name DaySummary
extends Control
## Shown after each day: what changed in every meter and why, in plain language.

signal continue_pressed

var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_report(report: Dictionary) -> void:
	close()
	var parts := UiKit.make_overlay(880.0)
	_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_theme_constant_override("separation", 8)

	var day_no := int(report.get("resolved_day", 0))
	box.add_child(UiKit.label("Day %d summary" % day_no, UiKit.FONT_TITLE, UiKit.COLOR_WARN, false))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	for m in report.get("meters", []):
		var before := int(m["before"])
		var after := int(m["after"])
		var change := "stayed the same"
		if after > before:
			change = "went UP by %d" % (after - before)
		elif after < before:
			change = "went DOWN by %d" % (before - after)
		body.add_child(UiKit.label("%s: %d -> %d  (%s)" % [m["label"], before, after, change], UiKit.FONT_BODY, UiKit.COLOR_TEXT))
		body.add_child(UiKit.label("   " + "  |  ".join(m["lines"]), UiKit.FONT_SMALL, UiKit.COLOR_MUTED))

	var storm: Dictionary = report.get("storm", {})
	if not storm.is_empty():
		body.add_child(UiKit.label("Solar storm: the crew took %d damage (shield level %d, %s)." % [
			storm["damage"], storm["shield"], "lockdown used" if storm["lockdown"] else "no full lockdown"],
			UiKit.FONT_BODY, UiKit.COLOR_BAD))

	var extras: Array = []
	extras.append_array(report.get("notes", []))
	extras.append_array(report.get("messages", []))
	if not extras.is_empty():
		body.add_child(UiKit.label("What else happened:", UiKit.FONT_BODY, UiKit.COLOR_WARN))
		for line in extras:
			body.add_child(UiKit.label("*  " + String(line), UiKit.FONT_SMALL))

	box.add_child(FactCard.make_fact(NasaData.next_fact()))

	var go := UiKit.button("See the end result" if bool(report.get("game_over", false)) else "Continue to Day %d" % (day_no + 1),
		UiKit.FONT_BODY, Vector2(0, 54))
	go.pressed.connect(func() -> void:
		close()
		continue_pressed.emit())
	box.add_child(go)
	add_child(_overlay)
	go.grab_focus()


func close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func is_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)

