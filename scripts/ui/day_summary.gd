class_name DaySummary
extends Control
## Daily summary screen reading directly from GameState.event_log.
## Shows what changed in each meter and why (including power cuts, event choices,
## and storm damage) in plain language, plus one non-repeating OSDR fact card.

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

	var day_no := int(report.get("resolved_day", GameState.day))
	var day_entries: Array[Dictionary] = GameState.get_day_events(day_no)
	var day_end_entry: Dictionary = report
	for entry in day_entries:
		if String(entry.get("type", "")) == "day_end":
			day_end_entry = entry

	box.add_child(UiKit.label(
		"END OF DAY %d — DAILY MISSION SUMMARY" % day_no,
		UiKit.FONT_TITLE, UiKit.COLOR_WARN, false
	))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# 1. What changed in each meter and why (from day_end entry in GameState.event_log)
	for m in day_end_entry.get("meters", []):
		var key := String(m["key"])
		var before := int(m["before"])
		var after := int(m["after"])
		var word := GameState.meter_word(key)
		var change := "● Stayed steady"
		var color := UiKit.COLOR_TEXT
		if after > before:
			change = "▲ Went up"
			color = UiKit.COLOR_GOOD
		elif after < before:
			change = "▼ Went down"
			color = UiKit.COLOR_WARN if word not in ["LOW!", "EMPTY!"] else UiKit.COLOR_BAD

		var strip := PanelContainer.new()
		strip.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_ROW, UiKit.COLOR_BORDER_DIM, 8, 6, 1))
		var sbox := VBoxContainer.new()
		sbox.add_theme_constant_override("separation", 3)
		strip.add_child(sbox)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := UiKit.label("%s: %s (%s)" % [String(m["label"]).to_upper(), word, change], 15, color, false)
		name_lbl.custom_minimum_size = Vector2(260, 0)
		row.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = GameState.battery_max() if key == "battery" else Rules.max_value(key)
		bar.value = after
		bar.custom_minimum_size = Vector2(160, 14)
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)

		var reasons: Array = m.get("lines", [])
		var why_str := ", ".join(reasons) if not reasons.is_empty() else "Steady today"
		row.add_child(UiKit.label("Why: " + why_str, 13, UiKit.COLOR_MUTED, true))
		sbox.add_child(row)
		body.add_child(strip)

	# 2. Event choices, power/water cuts, storm damage, and messages read from GameState.event_log
	var highlights: Array[String] = []
	for entry in day_entries:
		var etype := String(entry.get("type", ""))
		match etype:
			"event_choice":
				highlights.append("Event choice — %s" % String(entry.get("text", "")))
			"power_cut", "water_cut":
				highlights.append("System cut — %s" % String(entry.get("text", "")))
			"storm":
				var dmg := int(entry.get("damage", 0))
				var s_txt := String(entry.get("text", ""))
				highlights.append("Solar storm — %s (Health -%d)" % [s_txt, dmg])
			"penalty":
				highlights.append("Warning — %s" % String(entry.get("text", "")))

	for next_entry in GameState.get_day_events(day_no + 1):
		if String(next_entry.get("type", "")) == "message_delivered":
			highlights.append("Earth link — %s" % String(next_entry.get("text", "")))

	if not highlights.is_empty():
		body.add_child(UiKit.label("KEY EVENTS, POWER CUTS & STORMS TODAY:", 15, UiKit.COLOR_WARN))
		for line in highlights:
			body.add_child(UiKit.label("• " + line, UiKit.FONT_SMALL))

	# 3. Non-repeating OSDR fact card ("Saved NASA data")
	box.add_child(FactCard.make_fact(NasaData.next_fact()))

	var is_over := bool(day_end_entry.get("game_over", false))
	var go := UiKit.gold_button(
		"SEE MISSION RESULTS ▶" if is_over else "START DAY %d ▶" % (day_no + 1),
		16, Vector2(0, 46)
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
