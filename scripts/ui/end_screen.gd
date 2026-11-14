class_name EndScreen
extends Control
## Mission end screen showing win/loss, star rating (1-3), visual meter words,
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

	var title_text := "🎉 MISSION COMPLETE — YOU SURVIVED 10 DAYS!" if won else "MISSION ENDED — LET'S TRY AGAIN!"
	var title_color := UiKit.COLOR_GOOD if won else UiKit.COLOR_BAD
	box.add_child(UiKit.label(title_text, UiKit.FONT_TITLE, title_color))

	var stars := GameState.stars_earned
	var star_line := "Your Rating: %s (%d of 3 Stars)" % [UiKit.stars(stars, 3, " "), stars] if won else "Your Rating: ☆ ☆ ☆ (Keep Crew Health Good through Day 10 to win!)"
	box.add_child(UiKit.label(star_line, UiKit.FONT_BODY, UiKit.COLOR_WARN))

	var sh_stars := UiKit.stars(GameState.shield, Rules.max_value("shield"))
	var meters_summary := "Final Base Check — Health: %s  |  Battery: %s  |  Oxygen: %s  |  Food: %s  |  Water: %s  |  Shield: %s" % [
		GameState.meter_word("health"),
		GameState.meter_word("battery"),
		GameState.meter_word("oxygen"),
		GameState.meter_word("food"),
		GameState.meter_word("water"),
		sh_stars,
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

	var hints_heading := "Tips to earn all 3 Stars next time:" if (won and stars < 3) else ("What went wrong (and tips for next time):" if not won else "Awesome job, Commander!")
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
