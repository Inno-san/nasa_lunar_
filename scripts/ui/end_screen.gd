class_name EndScreen
extends Control
## Mission end screen showing win/loss, star rating (1-3), final meters, science score,
## "What went wrong" replay hints, and a non-repeating OSDR fact card.

signal play_again_requested
signal main_menu_requested

var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_end_screen() -> void:
	close()
	var won := GameState.mission_won
	AudioManager.play("win" if won else "lose")

	var parts := UiKit.make_overlay(880.0)
	_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_theme_constant_override("separation", 10)

	var title_text := "MISSION COMPLETE — YOU SURVIVED 10 DAYS!" if won else "MISSION ENDED — TRY AGAIN!"
	var title_color := UiKit.COLOR_GOOD if won else UiKit.COLOR_BAD
	box.add_child(UiKit.label(title_text, UiKit.FONT_TITLE, title_color))

	var stars := GameState.stars_earned
	var star_icons := ""
	for i in range(3):
		star_icons += "★ " if i < stars else "☆ "
	var star_line := "Rating: %s (%d / 3 Stars)" % [star_icons.strip_edges(), stars] if won else "Rating: ☆ ☆ ☆ (0 / 3 Stars — Crew Health needed: %d+)" % int(Rules.win_data().get("min_health", 0))
	box.add_child(UiKit.label(star_line, UiKit.FONT_BODY, UiKit.COLOR_WARN))

	var meters_summary := "Final Meters — Health: %d/%d  |  Science: %d  |  Battery: %d  |  Oxygen: %d  |  Food: %d  |  Water: %d  |  Shield: Lvl %d" % [
		GameState.health, Rules.max_value("health"),
		GameState.science,
		GameState.battery,
		GameState.oxygen,
		GameState.food,
		GameState.water,
		GameState.shield,
	]
	box.add_child(UiKit.label(meters_summary, UiKit.FONT_BODY))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	var hints_heading := "How to get all 3 stars next time:" if (won and stars < 3) else ("What went wrong (and tips for next time):" if not won else "Mission highlights:")
	body.add_child(UiKit.label(hints_heading, UiKit.FONT_BODY, UiKit.COLOR_WARN))
	for hint in ReplayHints.build():
		body.add_child(UiKit.label("• " + hint, UiKit.FONT_SMALL))

	body.add_child(FactCard.make_fact(NasaData.next_fact(), "Space Science Fact (End of Mission)"))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	box.add_child(btn_row)

	var replay_btn := UiKit.button("Play Again (Day 1)", UiKit.FONT_BODY, Vector2(240, 52))
	replay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_btn.pressed.connect(func() -> void:
		close()
		play_again_requested.emit()
	)
	btn_row.add_child(replay_btn)

	var menu_btn := UiKit.button("Main Menu", UiKit.FONT_BODY, Vector2(200, 52))
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.pressed.connect(func() -> void:
		close()
		main_menu_requested.emit()
	)
	btn_row.add_child(menu_btn)

	add_child(_overlay)
	replay_btn.grab_focus()


func close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func is_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)
