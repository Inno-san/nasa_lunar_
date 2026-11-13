extends Control
## Start menu with Play (including a loading briefing with a saved OSDR fact card),
## How to Play (3 short slides), Credits, and Sound Mute toggle.

const HOW_TO_SLIDES := [
	{
		"title": "Slide 1 of 3: Walk Around the Moon Base",
		"body": "You are in charge of a Lunar Outpost for 10 days!\n\n• Move with WASD, Arrow Keys, the on-screen D-pad, or click on the floor.\n• Walk up to any of the 5 rooms and press [E] (or click the room) to open its dashboard.\n• Walking is free! Using console buttons spends Action Points (6 AP per day) and Battery power.",
		"terms": ["battery", "oxygen"],
	},
	{
		"title": "Slide 2 of 3: Power, Air, Food & Delayed Messages",
		"body": "Keep your crew's Health at 50 or above through the end of Day 10!\n\n• Solar panels add +36 Power each day. If power runs short, the base turns off systems in order.\n• The Greenhouse grows fresh food, but harvests take 2 days to arrive.\n• Messages to Earth also take 2 days to get a reply — ask for storm forecasts early!",
		"terms": ["greenhouse", "comm_delay"],
	},
	{
		"title": "Slide 3 of 3: Solar Storms & The Radiation Shelter",
		"body": "Real NASA records inspire the solar storms on Days 4, 8, and 10!\n\n• Severity 1 storms give a 1-day warning. Stronger storms (Severity 2–3) only warn you if a Forecast from Earth arrived in time.\n• When the storm alarm rings, run to the Radiation Shelter (bottom center) and press START LOCKDOWN before the timer hits 0!\n• Upgrading your Shield and running experiments help you earn up to 3 Stars.",
		"terms": ["solar_storm", "radiation", "shielding"],
	},
]

var _modal_overlay: Control = null
var _slide_index: int = 0
var _mute_btn: Button = null


func _ready() -> void:
	_build_menu()
	AudioManager.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(AudioManager.muted)


func _build_menu() -> void:
	UiKit.clear_children(self)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.02, 0.10, 1.0)
	add_child(bg)

	var stars_decor := Label.new()
	stars_decor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stars_decor.offset_top = 18.0
	stars_decor.offset_bottom = 46.0
	stars_decor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_decor.add_theme_font_size_override("font_size", 15)
	stars_decor.add_theme_color_override("font_color", Color(0.68, 0.56, 0.96, 0.9))
	stars_decor.text = "★  NASA SPACE APPS CHALLENGE 2026 — JUNIOR ASTRONAUT MISSION TRAINER  ★"
	add_child(stars_decor)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 0)
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 14, 24, 20))
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := UiKit.label("LUNAR OUTPOST: MISSION 01", UiKit.FONT_HUGE, UiKit.COLOR_WARN, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := UiKit.label(
		"Manage power, oxygen, food, radiation shielding, and delayed Earth comms for 10 days on the Moon!\n(Game values are simplified for ages 7–12 — all NASA records are Saved NASA data.)",
		UiKit.FONT_SMALL, UiKit.COLOR_MUTED
	)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(FactCard.make_fact(NasaData.next_fact(), "Mission Briefing — Space Science Fact"))

	var btn_grid := HBoxContainer.new()
	btn_grid.add_theme_constant_override("separation", 12)
	box.add_child(btn_grid)

	var play_btn := UiKit.gold_button("▶  PLAY MISSION", 20, Vector2(210, 56))
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_play_button_pressed)
	btn_grid.add_child(play_btn)

	var how_btn := UiKit.button("How to Play (3 Slides)", 18, Vector2(210, 56))
	how_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how_btn.pressed.connect(_open_how_to_play)
	btn_grid.add_child(how_btn)

	var credits_btn := UiKit.button("Credits & Data", 18, Vector2(180, 56))
	credits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_btn.pressed.connect(_open_credits)
	btn_grid.add_child(credits_btn)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	box.add_child(bottom_row)

	_mute_btn = UiKit.button("Sound: ON", 16, Vector2(160, 44))
	_mute_btn.pressed.connect(func() -> void: AudioManager.toggle_mute())
	bottom_row.add_child(_mute_btn)

	var terms_label := UiKit.label("Tap a word to learn what it means:", 15, UiKit.COLOR_MUTED, false)
	bottom_row.add_child(terms_label)

	for term_id in ["solar_storm", "radiation", "shielding", "oxygen", "battery", "greenhouse", "comm_delay"]:
		var tbtn := UiKit.button(Explain.term_title(term_id), 14, Vector2(0, 38))
		tbtn.pressed.connect(Explain.show_term.bind(term_id))
		bottom_row.add_child(tbtn)

	play_btn.grab_focus()


func _on_mute_changed(is_muted: bool) -> void:
	if _mute_btn != null:
		_mute_btn.text = "Sound: MUTED" if is_muted else "Sound: ON"


func _on_play_button_pressed() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/lunar_base.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _close_modal() -> void:
	if _modal_overlay != null and is_instance_valid(_modal_overlay):
		_modal_overlay.queue_free()
	_modal_overlay = null


func _open_how_to_play() -> void:
	_slide_index = 0
	_render_slide()


func _render_slide() -> void:
	_close_modal()
	var slide: Dictionary = HOW_TO_SLIDES[_slide_index]
	var parts := UiKit.make_overlay(760.0)
	_modal_overlay = parts[0]
	var box: VBoxContainer = parts[1]

	box.add_child(UiKit.label(String(slide["title"]), UiKit.FONT_TITLE, UiKit.COLOR_WARN))
	box.add_child(UiKit.label(String(slide["body"]), UiKit.FONT_BODY))

	var term_row := HBoxContainer.new()
	term_row.add_theme_constant_override("separation", 8)
	term_row.add_child(UiKit.label("Tap to explain:", UiKit.FONT_SMALL, UiKit.COLOR_MUTED, false))
	for tid in slide["terms"]:
		var eb := UiKit.button("? " + Explain.term_title(String(tid)), 15, Vector2(0, 40))
		eb.pressed.connect(Explain.show_term.bind(String(tid)))
		term_row.add_child(eb)
	box.add_child(term_row)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	box.add_child(nav)

	var prev_btn := UiKit.button("◀ Back", 17, Vector2(140, 48))
	prev_btn.disabled = (_slide_index <= 0)
	prev_btn.pressed.connect(func() -> void:
		_slide_index = maxi(0, _slide_index - 1)
		_render_slide()
	)
	nav.add_child(prev_btn)

	var next_btn := UiKit.button("Next Slide ▶" if _slide_index < HOW_TO_SLIDES.size() - 1 else "Start Mission ▶", 17, Vector2(180, 48))
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(func() -> void:
		if _slide_index < HOW_TO_SLIDES.size() - 1:
			_slide_index += 1
			_render_slide()
		else:
			_close_modal()
			_on_play_button_pressed()
	)
	nav.add_child(next_btn)

	var close_btn := UiKit.button("Close", 17, Vector2(120, 48))
	close_btn.pressed.connect(_close_modal)
	nav.add_child(close_btn)

	add_child(_modal_overlay)
	next_btn.grab_focus()


func _open_credits() -> void:
	_close_modal()
	var parts := UiKit.make_overlay(820.0)
	_modal_overlay = parts[0]
	var box: VBoxContainer = parts[1]

	box.add_child(UiKit.label("Credits & Saved Data Sources", UiKit.FONT_TITLE, UiKit.COLOR_WARN))
	box.add_child(UiKit.label(
		"• NASA DONKI (CCMC Space Weather Database): Real May 2024 solar flare records (M5.1, X3.9, X8.7) used to inspire the Day 4, Day 8, and Day 10 storm scenarios (stored as Saved NASA data in data/donki_cached.json).\n"
		+ "• NASA Open Science Data Repository (OSDR): 17 space biology and astronaut health study records used for the daily 'Did you know?' fact cards (stored as Saved NASA data in data/osdr_facts.json).\n"
		+ "• Canadian Space Agency (CSA) — Food Production on the Moon Toolkit: Kid-friendly wording and educational concepts for the Lunar Greenhouse.\n"
		+ "• NASA Image and Video Library: Referenced in data documentation (this build uses lightweight vector UI shapes for instant web loading).\n\n"
		+ "Team: Lunar Outpost: Mission 01 Team (Amr Akram / Inno-san, Abdelrhman Mohamed / Abdelrhman-Mohamedd)\n\n"
		+ "Disclaimer: All NASA data in this game is cached ('Saved NASA data') and never fetched live. Game values and storm severity numbers are simplified for ages 7–12 and are not real engineering measurements. This project is an independent hackathon entry and is not endorsed by NASA or the Canadian Space Agency.",
		UiKit.FONT_SMALL
	))

	var close_btn := UiKit.button("Back to Menu", 18, Vector2(200, 50))
	close_btn.pressed.connect(_close_modal)
	box.add_child(close_btn)

	add_child(_modal_overlay)
	close_btn.grab_focus()
