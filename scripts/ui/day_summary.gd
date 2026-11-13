class_name DaySummary
extends Control
## Shown after each day: visual bars and plain words showing what went up, stayed steady, or went down.

signal continue_pressed

var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_report(report: Dictionary) -> void:
	close()
	var parts := UiKit.make_overlay(860.0)
	_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_theme_constant_override("separation", 8)

	var day_no := int(report.get("resolved_day", 0))
	box.add_child(UiKit.label("End of Day %d — How is the Base Doing?" % day_no, UiKit.FONT_TITLE, UiKit.COLOR_WARN, false))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	for m in report.get("meters", []):
		var key := String(m["key"])
		var before := int(m["before"])
		var after := int(m["after"])
		var word := GameState.meter_word(key)
		var change := "● Stayed steady"
		var color := UiKit.COLOR_TEXT
		if after > before:
			change = "▲ Went up!"
			color = UiKit.COLOR_GOOD
		elif after < before:
			change = "▼ Went down"
			color = UiKit.COLOR_WARN if word not in ["LOW!", "EMPTY!"] else UiKit.COLOR_BAD

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := UiKit.label("%s: %s (%s)" % [m["label"], word, change], UiKit.FONT_BODY, color, false)
		name_lbl.custom_minimum_size = Vector2(280, 0)
		row.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = GameState.battery_max() if key == "battery" else Rules.max_value(key)
		bar.value = after
		bar.custom_minimum_size = Vector2(180, 18)
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		body.add_child(row)

	var storm: Dictionary = report.get("storm", {})
	if not storm.is_empty():
		var storm_msg := "Solar storm passed! " + (
			"You locked down the shelter in time and protected the crew!"
			if bool(storm.get("lockdown", false))
			else "Remember to hide in the purple Radiation Shelter next time!"
		)
		body.add_child(UiKit.label(storm_msg, UiKit.FONT_BODY, UiKit.COLOR_WARN))

	var extras: Array = []
	extras.append_array(report.get("notes", []))
	extras.append_array(report.get("messages", []))
	if not extras.is_empty():
		body.add_child(UiKit.label("Important news today:", UiKit.FONT_BODY, UiKit.COLOR_WARN))
		for line in extras:
			body.add_child(UiKit.label("• " + String(line), UiKit.FONT_SMALL))

	box.add_child(FactCard.make_fact(NasaData.next_fact()))

	var go := UiKit.button(
		"See Mission Results ▶" if bool(report.get("game_over", false)) else "Start Day %d ▶" % (day_no + 1),
		UiKit.FONT_BODY, Vector2(0, 54)
	)
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
