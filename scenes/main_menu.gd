extends Control
## Main Menu matching the Lunar Outpost Mission 01 mockup:
## - Starry deep-space background, top-right Earth illustration, bottom Moon crater horizon
## - "MISSION 01" teal header, "Lunar Outpost" title, subtitle
## - Rounded white-bordered "Mission Briefing — Space Science Fact" card with line-art rover/helmet icon
## - Orange "Play Mission ->" CTA + white-outlined "How to Play (3 slides)" & "Credits & Data" buttons
## - Bottom bar with "Sound: On" teal pill switch and 7 vector-icon science word buttons with vertical dividers

const HOW_TO_SLIDES := [
	{
		"title": "Slide 1 of 3: Walk Around the Moon Base",
		"body": "You are in charge of a Lunar Outpost for 10 days!\n\n• Move with WASD, Arrow Keys, the on-screen D-pad, or click anywhere on the floor.\n• Walk up to any of the 5 rooms and press [E] (or click the room) to open its dashboard.\n• Walking is free! Using console buttons spends Action Points (6 AP per day) and Battery power.",
		"terms": ["battery", "oxygen"],
	},
	{
		"title": "Slide 2 of 3: Power, Air, Food & Delayed Messages",
		"body": "Keep your crew's Health at 50 or above through the end of Day 10!\n\n• Solar panels add +36 Power each day. If power runs short, the base turns off systems in order.\n• The Greenhouse grows fresh food, but harvests take 2 days to arrive.\n• Messages to Earth also take 2 days to get a reply — ask for storm forecasts early!",
		"terms": ["greenhouse", "comm_delay"],
	},
	{
		"title": "Slide 3 of 3: Solar Storms & The Radiation Shelter",
		"body": "Real NASA records inspire the solar storms on Days 4, 8, and 10!\n\n• Severity 1 storms give a 1-day warning. Stronger storms (Severity 2–3) only warn you if a Forecast from Earth arrived in time.\n• When the storm alarm rings, run to the Radiation Shelter and press LOCK DOWN before the timer hits 0!\n• Upgrading your Shield and running experiments help you earn up to 3 Stars.",
		"terms": ["solar_storm", "radiation", "shielding"],
	},
]

const COLOR_NAVY_BG := Color(0.02, 0.055, 0.12, 1.0)
const COLOR_CARD_BG := Color(0.027, 0.067, 0.145, 0.96)
const COLOR_TEAL := Color(0.24, 0.80, 0.74, 1.0)
const COLOR_ORANGE := Color(0.95, 0.64, 0.21, 1.0)
const COLOR_ORANGE_HOVER := Color(1.0, 0.73, 0.30, 1.0)
const COLOR_WHITE := Color(0.96, 0.98, 1.0, 1.0)
const COLOR_SUBTEXT := Color(0.84, 0.90, 0.96, 1.0)

var _modal_overlay: Control = null
var _slide_index: int = 0
var _sound_label: Label = null
var _sound_toggle: Control = null
var _menu_fact: Dictionary = {}


func _ready() -> void:
	_menu_fact = NasaData.next_fact()
	_build_menu()
	AudioManager.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(AudioManager.muted)


func _build_menu() -> void:
	UiKit.clear_children(self)

	# 1. Custom drawn backdrop (stars, Earth in top-right, Moon horizon with craters at bottom)
	var backdrop := _MenuBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 2. Main content container
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 76)
	root_margin.add_theme_constant_override("margin_right", 76)
	root_margin.add_theme_constant_override("margin_top", 34)
	root_margin.add_theme_constant_override("margin_bottom", 62)
	add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	root_margin.add_child(vbox)

	# Header block
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	vbox.add_child(header_box)

	var kicker := Label.new()
	kicker.text = "M I S S I O N   0 1"
	kicker.add_theme_font_size_override("font_size", 20)
	kicker.add_theme_color_override("font_color", COLOR_TEAL)
	header_box.add_child(kicker)

	var title := Label.new()
	title.text = "Lunar Outpost"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", COLOR_WHITE)
	header_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Explore the Moon! Can you survive for 10 days?"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", COLOR_SUBTEXT)
	header_box.add_child(subtitle)

	# 3. Mission Briefing — Space Science Fact Card
	var briefing_card := PanelContainer.new()
	briefing_card.custom_minimum_size = Vector2(0, 178)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.set_border_width_all(3)
	card_style.border_color = COLOR_WHITE
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	briefing_card.add_theme_stylebox_override("panel", card_style)
	vbox.add_child(briefing_card)

	var card_hbox := HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 26)
	briefing_card.add_child(card_hbox)

	# Left Rover/Astronaut line-art icon
	var rover_icon := _RoverArt.new()
	rover_icon.custom_minimum_size = Vector2(150, 128)
	card_hbox.add_child(rover_icon)

	# Vertical divider line inside card
	var vdiv := ColorRect.new()
	vdiv.custom_minimum_size = Vector2(2, 118)
	vdiv.color = Color(0.75, 0.82, 0.90, 0.7)
	card_hbox.add_child(vdiv)

	# Right text column inside card
	var fact_vbox := VBoxContainer.new()
	fact_vbox.add_theme_constant_override("separation", 8)
	fact_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fact_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_hbox.add_child(fact_vbox)

	var fact_title := Label.new()
	fact_title.text = "Mission Briefing — Space Science Fact"
	fact_title.add_theme_font_size_override("font_size", 22)
	fact_title.add_theme_color_override("font_color", COLOR_TEAL)
	fact_vbox.add_child(fact_title)

	var fact_body := Label.new()
	fact_body.text = String(_menu_fact.get("fact", "Astronauts study how plants and bodies adapt to space!"))
	fact_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact_body.add_theme_font_size_override("font_size", 20)
	fact_body.add_theme_color_override("font_color", COLOR_WHITE)
	fact_vbox.add_child(fact_body)

	var src_row := HBoxContainer.new()
	src_row.add_theme_constant_override("separation", 6)
	fact_vbox.add_child(src_row)

	var src_prefix := Label.new()
	src_prefix.text = "Source:"
	src_prefix.add_theme_font_size_override("font_size", 16)
	src_prefix.add_theme_color_override("font_color", COLOR_WHITE)
	src_row.add_child(src_prefix)

	var src_link := LinkButton.new()
	var sid := String(_menu_fact.get("study_id", "OSD-47"))
	var sdate := String(_menu_fact.get("date", "2015-05-19"))
	var slink := String(_menu_fact.get("link", "https://osdr.nasa.gov/bio/repo"))
	src_link.text = "NASA Open study page (%s, %s — Saved NASA data)" % [sid, sdate]
	src_link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	src_link.uri = slink
	src_link.add_theme_font_size_override("font_size", 16)
	src_link.add_theme_color_override("font_color", COLOR_SUBTEXT)
	src_link.add_theme_color_override("font_hover_color", COLOR_TEAL)
	src_row.add_child(src_link)

	# 4. Three Main Buttons Row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 22)
	vbox.add_child(btn_row)

	var play_btn := _make_orange_cta("Play Mission   →")
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_play_button_pressed)
	btn_row.add_child(play_btn)

	var how_btn := _make_outline_btn("How to Play (3 slides)")
	how_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how_btn.pressed.connect(_open_how_to_play)
	btn_row.add_child(how_btn)

	var credits_btn := _make_outline_btn("Credits & Data")
	credits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_btn.pressed.connect(_open_credits)
	btn_row.add_child(credits_btn)

	# Spacer before bottom bar
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 5. Bottom Row: Sound toggle pill + 7 vertical-divided science term icons
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 0)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)

	# Sound: On + teal pill switch
	var sound_box := HBoxContainer.new()
	sound_box.add_theme_constant_override("separation", 12)
	sound_box.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_box.custom_minimum_size = Vector2(190, 64)
	bottom_row.add_child(sound_box)

	_sound_label = Label.new()
	_sound_label.text = "Sound: On"
	_sound_label.add_theme_font_size_override("font_size", 20)
	_sound_label.add_theme_color_override("font_color", COLOR_WHITE)
	sound_box.add_child(_sound_label)

	_sound_toggle = _PillToggle.new()
	_sound_toggle.custom_minimum_size = Vector2(58, 30)
	_sound_toggle.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			AudioManager.toggle_mute()
	)
	sound_box.add_child(_sound_toggle)

	var term_specs := [
		["solar_storm", "Solar storm"],
		["radiation", "Radiation"],
		["shielding", "Shielding"],
		["oxygen", "Oxygen"],
		["battery", "Battery"],
		["greenhouse", "Greenhouse"],
		["comm_delay", "Delay"],
	]
	for spec in term_specs:
		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(2, 54)
		sep.color = Color(0.75, 0.82, 0.90, 0.65)
		bottom_row.add_child(sep)

		var tid: String = spec[0]
		var tlabel: String = spec[1]
		var item_btn := _make_term_icon_btn(tid, tlabel)
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_row.add_child(item_btn)

	play_btn.grab_focus()


func _make_orange_cta(text_str: String) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(320, 68)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 25)
	btn.add_theme_color_override("font_color", Color(0.03, 0.07, 0.14, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.02, 0.05, 0.10, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.02, 0.05, 0.10, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_ORANGE
	normal.set_corner_radius_all(14)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_ORANGE_HOVER

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _make_outline_btn(text_str: String) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(280, 68)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", COLOR_WHITE)
	btn.add_theme_color_override("font_hover_color", COLOR_TEAL)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_CARD_BG
	normal.set_border_width_all(3)
	normal.border_color = COLOR_WHITE
	normal.set_corner_radius_all(14)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = COLOR_TEAL
	hover.bg_color = Color(0.05, 0.12, 0.24, 0.98)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _make_term_icon_btn(term_id: String, label_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(115, 64)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", empty_style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon_center)

	var icon := _TermIcon.new(term_id)
	icon.custom_minimum_size = Vector2(36, 34)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COLOR_WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)

	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			Explain.show_term(term_id)
	)
	panel.mouse_entered.connect(func() -> void:
		lbl.add_theme_color_override("font_color", COLOR_TEAL)
		icon.highlighted = true
		icon.queue_redraw()
	)
	panel.mouse_exited.connect(func() -> void:
		lbl.add_theme_color_override("font_color", COLOR_WHITE)
		icon.highlighted = false
		icon.queue_redraw()
	)
	return panel


func _on_mute_changed(is_muted: bool) -> void:
	if _sound_label != null:
		_sound_label.text = "Sound: Off" if is_muted else "Sound: On"
	if _sound_toggle != null:
		_sound_toggle.set("is_on", not is_muted)
		_sound_toggle.queue_redraw()


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

	box.add_child(UiKit.label(String(slide["title"]), UiKit.FONT_TITLE, COLOR_TEAL))
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

	var next_btn := UiKit.gold_button("NEXT SLIDE ▶" if _slide_index < HOW_TO_SLIDES.size() - 1 else "START MISSION ▶", 17, Vector2(180, 48))
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

	box.add_child(UiKit.label("Credits & Saved Data Sources", UiKit.FONT_TITLE, COLOR_TEAL))
	box.add_child(UiKit.label(
		"• NASA DONKI (CCMC Space Weather Database): Real May 2024 solar flare records (M5.1, X3.9, X8.7) used to inspire the Day 4, Day 8, and Day 10 storm scenarios (stored as Saved NASA data in data/donki_cached.json).\n"
		+ "• NASA Open Science Data Repository (OSDR): 17 space biology and astronaut health study records used for the daily 'Did you know?' fact cards (stored as Saved NASA data in data/osdr_facts.json).\n"
		+ "• Canadian Space Agency (CSA) — Food Production on the Moon Toolkit: Kid-friendly wording and educational concepts for the Lunar Greenhouse.\n"
		+ "• NASA Image and Video Library: Referenced in data documentation (this build uses lightweight vector UI shapes for instant web loading).\n\n"
		+ "Team: Lunar Outpost: Mission 01 Team (Amr Akram / Inno-san, Abdelrhman Mohamed / Abdelrhman-Mohamedd)\n\n"
		+ "Disclaimer: All NASA data in this game is cached ('Saved NASA data') and never fetched live. Game values and storm severity numbers are simplified for ages 7–12 and are not real engineering measurements. This project is an independent hackathon entry and is not endorsed by NASA or the Canadian Space Agency.",
		UiKit.FONT_SMALL
	))

	var close_btn := UiKit.gold_button("BACK TO MENU", 16, Vector2(200, 48))
	close_btn.pressed.connect(_close_modal)
	box.add_child(close_btn)

	add_child(_modal_overlay)
	close_btn.grab_focus()


# ============================================================================
# Custom Vector Art Controls for the Main Menu
# ============================================================================

class _MenuBackdrop extends Control:
	func _draw() -> void:
		var rect := get_rect()
		draw_rect(rect, COLOR_NAVY_BG)

		# Star dots
		var dots := [
			Vector2(36, 42), Vector2(368, 22), Vector2(495, 58), Vector2(688, 128),
			Vector2(782, 46), Vector2(890, 96), Vector2(1062, 148), Vector2(1118, 212),
			Vector2(30, 380), Vector2(1248, 392), Vector2(1224, 520), Vector2(46, 560),
		]
		for p in dots:
			draw_circle(p, 2.0, Color(0.95, 0.98, 1.0, 0.85))

		# 4-point sparkles
		_draw_sparkle(Vector2(572, 38), 7.0)
		_draw_sparkle(Vector2(990, 44), 11.0)
		_draw_sparkle(Vector2(1242, 182), 8.0)

		# Top-right Earth globe
		var ec := Vector2(rect.size.x - 114.0, 90.0)
		var er := 52.0
		draw_circle(ec, er, Color(0.11, 0.43, 0.68, 1.0))
		draw_arc(ec, er - 3.0, PI * 0.55, PI * 1.35, 32, Color(0.08, 0.32, 0.52, 0.9), 6.0)
		# Green continents
		draw_colored_polygon(PackedVector2Array([
			ec + Vector2(-24, -36), ec + Vector2(-4, -42), ec + Vector2(10, -24),
			ec + Vector2(4, -6), ec + Vector2(-12, -2), ec + Vector2(-26, -18),
		]), Color(0.35, 0.75, 0.44, 1.0))
		draw_colored_polygon(PackedVector2Array([
			ec + Vector2(2, 2), ec + Vector2(20, 8), ec + Vector2(26, 26),
			ec + Vector2(10, 44), ec + Vector2(-2, 32), ec + Vector2(-4, 14),
		]), Color(0.35, 0.75, 0.44, 1.0))
		draw_colored_polygon(PackedVector2Array([
			ec + Vector2(26, -24), ec + Vector2(42, -14), ec + Vector2(44, 8),
			ec + Vector2(30, 12), ec + Vector2(24, -6),
		]), Color(0.35, 0.75, 0.44, 1.0))

		# Bottom Lunar surface curve + craters
		var base_y := rect.size.y - 44.0
		var moon_poly := PackedVector2Array()
		moon_poly.append(Vector2(0, rect.size.y))
		for i in range(33):
			var t := float(i) / 32.0
			var x := t * rect.size.x
			var wave := sin(t * PI) * 14.0 + cos(t * PI * 3.0) * 4.0
			moon_poly.append(Vector2(x, base_y - wave))
		moon_poly.append(Vector2(rect.size.x, rect.size.y))
		draw_colored_polygon(moon_poly, Color(0.55, 0.59, 0.65, 1.0))

		# Craters on the moon horizon
		_draw_crater(Vector2(92, rect.size.y - 24), Vector2(42, 10))
		_draw_crater(Vector2(215, rect.size.y - 12), Vector2(26, 7))
		_draw_crater(Vector2(490, rect.size.y - 34), Vector2(20, 6))
		_draw_crater(Vector2(695, rect.size.y - 20), Vector2(38, 10))
		_draw_crater(Vector2(1025, rect.size.y - 22), Vector2(54, 12))
		_draw_crater(Vector2(1190, rect.size.y - 16), Vector2(30, 8))

	func _draw_sparkle(c: Vector2, r: float) -> void:
		var col := Color(0.96, 0.99, 1.0, 0.95)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.22, -r * 0.22),
			c + Vector2(r, 0), c + Vector2(r * 0.22, r * 0.22),
			c + Vector2(0, r), c + Vector2(-r * 0.22, r * 0.22),
			c + Vector2(-r, 0), c + Vector2(-r * 0.22, -r * 0.22),
		]), col)

	func _draw_crater(c: Vector2, radii: Vector2) -> void:
		var pts := PackedVector2Array()
		for i in range(24):
			var a := float(i) / 24.0 * TAU
			pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
		draw_colored_polygon(pts, Color(0.36, 0.40, 0.46, 1.0))


class _RoverArt extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var w := Color(0.96, 0.98, 1.0, 1.0)
		# Ground line
		draw_line(Vector2(12, c.y + 52), Vector2(size.x - 12, c.y + 52), w, 3.0)
		# Astronaut helmet dome (top)
		var hc := Vector2(c.x + 6, c.y - 16)
		draw_arc(hc, 32.0, 0.0, TAU, 36, w, 3.5)
		# Visor inside helmet
		draw_arc(hc + Vector2(4, 0), 21.0, -PI * 0.45, PI * 0.55, 24, w, 2.5)
		draw_line(hc + Vector2(4, -21), hc + Vector2(4, 21), w, 2.5)
		# Rover chassis below helmet
		draw_rect(Rect2(c.x - 36, c.y + 12, 78, 22), COLOR_CARD_BG, true)
		draw_rect(Rect2(c.x - 36, c.y + 12, 78, 22), w, false, 3.0)
		# Three rover wheels
		for wx in [c.x - 30, c.x - 4, c.x + 30]:
			var wc := Vector2(wx, c.y + 38)
			draw_circle(wc, 13.0, COLOR_CARD_BG)
			draw_arc(wc, 13.0, 0.0, TAU, 24, w, 3.0)
			draw_circle(wc, 4.5, w)


class _PillToggle extends Control:
	var is_on: bool = true

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var r := size.y * 0.5
		var track_col := COLOR_TEAL if is_on else Color(0.28, 0.34, 0.44, 1.0)
		draw_circle(Vector2(r, r), r, track_col)
		draw_circle(Vector2(size.x - r, r), r, track_col)
		draw_rect(Rect2(r, 0, size.x - 2.0 * r, size.y), track_col, true)
		var knob_x := (size.x - r) if is_on else r
		draw_circle(Vector2(knob_x, r), r - 3.5, COLOR_WHITE)


class _TermIcon extends Control:
	var term_id: String = ""
	var highlighted: bool = false

	func _init(tid: String = "") -> void:
		term_id = tid

	func _draw() -> void:
		var col := COLOR_TEAL if highlighted else COLOR_WHITE
		var c := size * 0.5
		match term_id:
			"solar_storm":
				draw_circle(c, 7.5, col)
				for i in range(8):
					var a := float(i) * PI * 0.25
					var dir := Vector2(cos(a), sin(a))
					draw_line(c + dir * 10.5, c + dir * 15.5, col, 2.5)
			"radiation":
				draw_circle(c, 3.2, col)
				for i in range(3):
					var a0 := float(i) * TAU / 3.0 - PI / 6.0 - 0.38
					var a1 := a0 + 0.76
					draw_arc(c, 10.5, a0, a1, 10, col, 6.0)
			"shielding":
				var pts := PackedVector2Array([
					c + Vector2(0, -14), c + Vector2(12, -9), c + Vector2(10, 4),
					c + Vector2(0, 14), c + Vector2(-10, 4), c + Vector2(-12, -9),
					c + Vector2(0, -14),
				])
				draw_polyline(pts, col, 2.8)
			"oxygen":
				var pts := PackedVector2Array([
					c + Vector2(0, -14), c + Vector2(10, 2), c + Vector2(7, 11),
					c + Vector2(0, 14), c + Vector2(-7, 11), c + Vector2(-10, 2),
					c + Vector2(0, -14),
				])
				draw_polyline(pts, col, 2.8)
				draw_circle(c + Vector2(0, 5), 3.0, col)
			"battery":
				draw_rect(Rect2(c.x - 14, c.y - 9, 25, 18), col, false, 2.6)
				draw_rect(Rect2(c.x + 11, c.y - 4, 4, 8), col, true)
				draw_rect(Rect2(c.x - 9, c.y - 4, 15, 8), col, true)
			"greenhouse":
				draw_arc(c + Vector2(0, 10), 14.0, PI, TAU, 20, col, 2.6)
				draw_line(c + Vector2(-16, 10), c + Vector2(16, 10), col, 2.6)
				draw_line(c + Vector2(0, 10), c + Vector2(0, 1), col, 2.4)
				draw_arc(c + Vector2(-4, 2), 4.0, -PI * 0.8, 0.2, 8, col, 2.2)
				draw_arc(c + Vector2(4, 2), 4.0, PI * 0.8, PI * 1.8, 8, col, 2.2)
			"comm_delay":
				draw_arc(c, 13.0, 0.0, TAU, 28, col, 2.6)
				draw_line(c, c + Vector2(0, -7.5), col, 2.5)
				draw_line(c, c + Vector2(6.0, 0), col, 2.5)
