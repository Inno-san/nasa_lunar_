extends Control
## Sci-fi cosmic purple & golden-amber Dashboard matching the reference layout:
## - Top chamfered tab bar + circular '✕' close button
## - Left sidebar ("ALL ROOMS" + golden "VIEW ON BASE" button + 5 selectable room cards with orb icons)
## - Top-center glowing circular orb emblem + Top-right "RESOURCES OF THE SELECTED ROOM" chamfered panel
## - Middle sub-tab header ("CONTROLS" | "SCIENCE GLOSSARY")
## - Bottom chamfered table of horizontal action rows with toggle indicators and golden CTA buttons.

signal dashboard_visibility_changed(is_open: bool)
signal lockdown_requested

const ROOM_META := {
	"power_station": {
		"name": "POWER STATION",
		"short": "SOLAR & BATTERY",
		"color": Color(0.98, 0.76, 0.18, 1.0),
		"accent": Color(1.0, 0.92, 0.45, 1.0),
	},
	"life_support": {
		"name": "LIFE SUPPORT",
		"short": "OXYGEN GENERATOR",
		"color": Color(0.22, 0.78, 0.98, 1.0),
		"accent": Color(0.65, 0.95, 1.0, 1.0),
	},
	"greenhouse": {
		"name": "GREENHOUSE",
		"short": "CROPS & WATER",
		"color": Color(0.32, 0.88, 0.48, 1.0),
		"accent": Color(0.72, 1.0, 0.78, 1.0),
	},
	"radiation_shelter": {
		"name": "SHELTER",
		"short": "STORM SHIELD",
		"color": Color(0.68, 0.38, 1.0, 1.0),
		"accent": Color(0.88, 0.72, 1.0, 1.0),
	},
	"comms_room": {
		"name": "COMMS ROOM",
		"short": "EARTH LINK",
		"color": Color(0.38, 0.58, 1.0, 1.0),
		"accent": Color(0.75, 0.85, 1.0, 1.0),
	},
}

const ROOM_ORDER := ["power_station", "life_support", "greenhouse", "radiation_shelter", "comms_room"]

var current_facility_id: String = "power_station"
var current_top_tab: String = "operations"
var current_sub_tab: String = "controls"

var top_tabs_box: HBoxContainer
var sidebar_list: VBoxContainer
var orb_canvas: Control
var orb_title_label: Label
var resources_title_label: Label
var resources_list: VBoxContainer
var sub_tabs_box: HBoxContainer
var table_headers: HBoxContainer
var rows_vbox: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameState.state_changed.connect(_on_state_changed)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.01, 0.06, 0.72)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	var main_root := Control.new()
	main_root.anchor_left = 0.5
	main_root.anchor_right = 0.5
	main_root.anchor_top = 0.5
	main_root.anchor_bottom = 0.5
	main_root.offset_left = -470.0
	main_root.offset_right = 470.0
	main_root.offset_top = -275.0
	main_root.offset_bottom = 265.0
	add_child(main_root)

	var tab_frame := PanelContainer.new()
	tab_frame.offset_left = 135.0
	tab_frame.offset_right = 805.0
	tab_frame.offset_top = 0.0
	tab_frame.offset_bottom = 42.0
	tab_frame.add_theme_stylebox_override("panel", UiKit.tab_style(true))
	main_root.add_child(tab_frame)

	top_tabs_box = HBoxContainer.new()
	top_tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_tabs_box.add_theme_constant_override("separation", 36)
	tab_frame.add_child(top_tabs_box)

	var outer_panel := PanelContainer.new()
	outer_panel.offset_left = 0.0
	outer_panel.offset_right = 940.0
	outer_panel.offset_top = 38.0
	outer_panel.offset_bottom = 540.0
	outer_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 8, 14, 2))
	main_root.add_child(outer_panel)

	var inner_panel := PanelContainer.new()
	inner_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_PANEL, UiKit.COLOR_BORDER_DIM, 14, 10, 2))
	outer_panel.add_child(inner_panel)

	var close_btn := UiKit.close_circle_button()
	close_btn.position = Vector2(920, 24)
	close_btn.pressed.connect(close_dashboard)
	main_root.add_child(close_btn)

	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 18)
	inner_panel.add_child(body_hbox)

	_build_sidebar_frame(body_hbox)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(right_vbox)

	_build_top_status_section(right_vbox)
	_build_bottom_table_section(right_vbox)


func _build_sidebar_frame(body_hbox: HBoxContainer) -> void:
	var sidebar_frame := PanelContainer.new()
	sidebar_frame.custom_minimum_size = Vector2(185, 0)
	sidebar_frame.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 8, 8, 2))
	body_hbox.add_child(sidebar_frame)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 8)
	sidebar_frame.add_child(side_vbox)

	var all_rooms_header := PanelContainer.new()
	all_rooms_header.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.28, 0.12, 0.62, 1.0), UiKit.COLOR_BORDER, 8, 6, 1))
	var ar_lbl := UiKit.label("ALL ROOMS", 13, UiKit.COLOR_TEXT, false)
	ar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	all_rooms_header.add_child(ar_lbl)
	side_vbox.add_child(all_rooms_header)

	var map_btn := UiKit.gold_button("SELECT ON MAP", 12, Vector2(0, 30))
	map_btn.tooltip_text = "Close this window and walk around the Moon base."
	map_btn.pressed.connect(close_dashboard)
	side_vbox.add_child(map_btn)

	sidebar_list = VBoxContainer.new()
	sidebar_list.add_theme_constant_override("separation", 6)
	sidebar_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(sidebar_list)


func _build_top_status_section(right_vbox: VBoxContainer) -> void:
	var top_half := HBoxContainer.new()
	top_half.add_theme_constant_override("separation", 18)
	top_half.custom_minimum_size = Vector2(0, 185)
	right_vbox.add_child(top_half)

	var orb_col := VBoxContainer.new()
	orb_col.custom_minimum_size = Vector2(180, 180)
	orb_col.alignment = BoxContainer.ALIGNMENT_CENTER
	orb_col.add_theme_constant_override("separation", 6)
	top_half.add_child(orb_col)

	orb_canvas = Control.new()
	orb_canvas.custom_minimum_size = Vector2(130, 130)
	orb_canvas.draw.connect(_draw_orb_emblem)
	orb_col.add_child(orb_canvas)

	orb_title_label = UiKit.label("POWER STATION", 18, UiKit.COLOR_ACCENT, false)
	orb_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb_col.add_child(orb_title_label)

	var res_panel := PanelContainer.new()
	res_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 14, 10, 2))
	top_half.add_child(res_panel)

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 6)
	res_panel.add_child(res_vbox)

	resources_title_label = UiKit.label("STATUS OF THE SELECTED ROOM", 14, UiKit.COLOR_TEXT, false)
	resources_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_vbox.add_child(resources_title_label)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UiKit.COLOR_BORDER_DIM
	res_vbox.add_child(div)

	resources_list = VBoxContainer.new()
	resources_list.add_theme_constant_override("separation", 6)
	res_vbox.add_child(resources_list)


func _build_bottom_table_section(right_vbox: VBoxContainer) -> void:
	var sub_tab_row := HBoxContainer.new()
	sub_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(sub_tab_row)

	var sub_tab_frame := PanelContainer.new()
	sub_tab_frame.add_theme_stylebox_override("panel", UiKit.tab_style(true))
	sub_tab_row.add_child(sub_tab_frame)

	sub_tabs_box = HBoxContainer.new()
	sub_tabs_box.add_theme_constant_override("separation", 28)
	sub_tab_frame.add_child(sub_tabs_box)

	var table_panel := PanelContainer.new()
	table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER, 12, 10, 2))
	right_vbox.add_child(table_panel)

	var table_vbox := VBoxContainer.new()
	table_vbox.add_theme_constant_override("separation", 6)
	table_panel.add_child(table_vbox)

	table_headers = HBoxContainer.new()
	table_headers.add_theme_constant_override("separation", 8)
	table_vbox.add_child(table_headers)

	var rows_scroll := ScrollContainer.new()
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_vbox.add_child(rows_scroll)

	rows_vbox = VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 6)
	rows_scroll.add_child(rows_vbox)


func _draw_orb_emblem() -> void:
	var meta: Dictionary = ROOM_META.get(current_facility_id, ROOM_META["power_station"])
	var col: Color = meta["color"]
	var acc: Color = meta["accent"]
	var c := orb_canvas.size * 0.5

	# Outer soft purple/colored glow rings
	for i in range(6, 0, -1):
		var r := 38.0 + float(i) * 4.5
		var a := 0.04 * float(7 - i)
		orb_canvas.draw_circle(c, r, Color(col.r, col.g, col.b, a))

	# Main planet/orb body
	orb_canvas.draw_circle(c, 40.0, col.darkened(0.35))
	orb_canvas.draw_circle(c + Vector2(-5, -5), 34.0, col)
	orb_canvas.draw_circle(c + Vector2(-12, -12), 20.0, acc)
	orb_canvas.draw_circle(c + Vector2(-16, -16), 8.0, Color(1, 1, 1, 0.65))
	# Crisp neon ring
	orb_canvas.draw_arc(c, 41.0, 0.0, TAU, 48, UiKit.COLOR_BORDER, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_dashboard()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if UiKit.is_left_click(event):
		close_dashboard()


func open_dashboard(facility_id: String) -> void:
	current_facility_id = facility_id if ROOM_META.has(facility_id) else "power_station"
	current_top_tab = "operations"
	current_sub_tab = "controls"
	visible = true
	dashboard_visibility_changed.emit(true)
	_refresh_contents()


func close_dashboard() -> void:
	if not visible:
		return
	visible = false
	dashboard_visibility_changed.emit(false)


func _on_state_changed() -> void:
	if visible:
		_refresh_contents()


func _refresh_contents() -> void:
	_build_top_tabs()
	_build_sidebar()
	orb_canvas.queue_redraw()
	var meta: Dictionary = ROOM_META.get(current_facility_id, ROOM_META["power_station"])
	orb_title_label.text = String(meta["name"])
	_build_resources_panel(meta)
	_build_sub_tabs(meta)
	_build_rows(meta)


func _add_flat_tab(parent: Container, label_txt: String, font_size: int, is_sel: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.text = label_txt
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", UiKit.COLOR_TEXT if is_sel else UiKit.COLOR_MUTED)
	btn.pressed.connect(on_press)
	parent.add_child(btn)
	return btn


func _build_top_tabs() -> void:
	UiKit.clear_children(top_tabs_box)
	for tab_def in [
		["information", "INFORMATION"],
		["buildings", "ROOMS"],
		["operations", "OPERATIONS"],
		["statistics", "BASE LOG"],
	]:
		var tid: String = tab_def[0]
		var btn := _add_flat_tab(top_tabs_box, tab_def[1], 16, current_top_tab == tid, func() -> void:
			current_top_tab = tid
			_refresh_contents()
		)
		btn.add_theme_color_override("font_hover_color", UiKit.COLOR_GOLD_HOVER)


func _build_sidebar() -> void:
	UiKit.clear_children(sidebar_list)
	for raw_fid in ROOM_ORDER:
		var fid: String = String(raw_fid)
		var m: Dictionary = ROOM_META[fid]
		var is_sel: bool = (fid == current_facility_id)
		var card := PanelContainer.new()
		var bg := UiKit.COLOR_SIDE_SELECTED if is_sel else Color(0.12, 0.07, 0.22, 0.85)
		var brd := UiKit.COLOR_GOLD if is_sel else UiKit.COLOR_BORDER_DIM
		card.add_theme_stylebox_override("panel", UiKit.panel_style(bg, brd, 8, 6, 1))
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if UiKit.is_left_click(ev):
				current_facility_id = fid
				current_top_tab = "operations"
				_refresh_contents()
		)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(22, 22)
		dot.color = m["color"]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)

		var n_lbl := UiKit.label(String(m["name"]), 13, UiKit.COLOR_TEXT, false)
		n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(n_lbl)

		var s_lbl := UiKit.label(String(m["short"]), 10, UiKit.COLOR_MUTED, false)
		s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(s_lbl)

		sidebar_list.add_child(card)


func _build_resources_panel(meta: Dictionary) -> void:
	UiKit.clear_children(resources_list)
	resources_title_label.text = "RESOURCES & STATUS OF " + String(meta["name"])

	if current_top_tab == "information":
		resources_list.add_child(UiKit.label(
			"• Day %d of %d   |   Actions Left: %s\n• %s" % [
				GameState.day, Rules.mission_days(), GameState.ap_dots(), GameState.coach_hint()
			], 14, UiKit.COLOR_TEXT
		))
		return
	if current_top_tab == "statistics":
		var start_idx := maxi(0, GameState.daily_log.size() - 4)
		for i in range(start_idx, GameState.daily_log.size()):
			resources_list.add_child(UiKit.label("• " + GameState.daily_log[i], 13, UiKit.COLOR_TEXT))
		return

	_add_res_line("⚡", Color(0.98, 0.78, 0.2), "BATTERY", "%s  (%s)" % [GameState.meter_word("battery").to_upper(), GameState.meter_trend("battery").to_upper()])
	_add_res_line("🫧", Color(0.3, 0.85, 1.0), "OXYGEN", "%s  (%s)" % [GameState.meter_word("oxygen").to_upper(), GameState.meter_trend("oxygen").to_upper()])
	_add_res_line("🌱", Color(0.4, 0.92, 0.5), "FOOD", "%s  (GREENHOUSE: %s)" % [GameState.meter_word("food").to_upper(), GameState.greenhouse_mode.to_upper()])
	_add_res_line("💧", Color(0.45, 0.68, 1.0), "WATER", "%s  (%s)" % [GameState.meter_word("water").to_upper(), GameState.meter_trend("water").to_upper()])
	var sh_stars := UiKit.stars(GameState.shield, Rules.max_value("shield"))
	_add_res_line("🛡️", Color(0.75, 0.5, 1.0), "SHIELD & HEALTH", "SHIELD %s  |  HEALTH (%s)" % [sh_stars, GameState.meter_word("health").to_upper()])


func _add_res_line(icon_txt: String, col: Color, name_txt: String, val_txt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := UiKit.label(icon_txt, 14, col, false)
	icon.custom_minimum_size = Vector2(22, 0)
	row.add_child(icon)
	var lbl := UiKit.label("%s  (%s)" % [name_txt, val_txt], 13, UiKit.COLOR_TEXT, false)
	row.add_child(lbl)
	resources_list.add_child(row)


func _build_sub_tabs(_meta: Dictionary) -> void:
	UiKit.clear_children(sub_tabs_box)
	for st in [
		["controls", "CONTROLS & MODES"],
		["glossary", "SCIENCE WORDS (?)"],
	]:
		var sid: String = st[0]
		_add_flat_tab(sub_tabs_box, st[1], 15, current_sub_tab == sid, func() -> void:
			current_sub_tab = sid
			_refresh_contents()
		)


func _build_rows(_meta: Dictionary) -> void:
	UiKit.clear_children(table_headers)
	UiKit.clear_children(rows_vbox)

	if current_sub_tab == "glossary":
		for term_id in ["solar_storm", "radiation", "shielding", "oxygen", "battery", "greenhouse", "comm_delay"]:
			_add_table_row(
				"?",
				UiKit.COLOR_ACCENT,
				Explain.term_title(term_id).to_upper(),
				"TAP TO READ",
				false,
				Explain.term_text(term_id),
				"EXPLAIN",
				true,
				func() -> void: Explain.show_term(term_id)
			)
		return

	_add_header_col("SYSTEM / MODE", 220)
	_add_header_col("SETTING", 90)
	_add_header_col("ACTIVE", 70)
	_add_header_col("WHAT IT DOES", 220)
	_add_header_col("COMMAND", 100)

	match current_facility_id:
		"power_station":
			_add_action_row("☀", Color(1, 0.82, 0.2), "CLEAN SOLAR PANELS", "READY", false, "KEEPS SUNLIGHT STRONG", "CLEAN", "repair_panel", null)
			_add_action_row("🔬", Color(0.85, 0.55, 1.0), "SCIENCE EXPERIMENT", "STAR GOAL", false, "EARNS SCIENCE FOR 3 STARS", "RESEARCH", "experiment", null)

		"life_support":
			_add_action_row("🫧", Color(0.35, 0.85, 1.0), "NORMAL MODE", "BALANCED", GameState.life_support_mode == "normal", "KEEPS OXYGEN STEADY", "SELECT", "set_life_support", "normal")
			_add_action_row("🫧", Color(0.3, 0.95, 0.7), "HIGH MODE", "EXTRA AIR", GameState.life_support_mode == "high", "FILLS OXYGEN UP FAST", "SELECT", "set_life_support", "high")
			_add_action_row("🫧", Color(0.95, 0.75, 0.3), "ECO MODE", "LOW POWER", GameState.life_support_mode == "eco", "SAVES POWER (AIR DROPS)", "SELECT", "set_life_support", "eco")
			_add_action_row("⚡", Color(0.4, 0.95, 1.0), "EMERGENCY OXYGEN", "INSTANT", false, "QUICK BURST OF FRESH AIR", "BOOST", "emergency_oxygen", null)

		"greenhouse":
			_add_action_row("🌱", Color(0.4, 0.92, 0.5), "LOW HARVEST", "BALANCED", GameState.greenhouse_mode == "low", "STEADY SMALL HARVEST", "SELECT", "set_greenhouse", "low")
			_add_action_row("🌿", Color(0.2, 1.0, 0.55), "HIGH HARVEST", "BIG CROP", GameState.greenhouse_mode == "high", "GROWS LOTS OF FOOD", "SELECT", "set_greenhouse", "high")
			_add_action_row("⏸", Color(0.75, 0.7, 0.85), "GREENHOUSE OFF", "PAUSED", GameState.greenhouse_mode == "off", "SAVES WATER & POWER", "SELECT", "set_greenhouse", "off")
			_add_action_row("🔧", Color(0.95, 0.78, 0.25), "FIX WATER PUMP", "REPAIR", false, "FIXES BROKEN PUMP", "REPAIR", "repair_pump", null)

		"radiation_shelter":
			if GameState.phase == GameState.PHASE_STORM:
				_add_table_row(
					"🚨", Color(1.0, 0.35, 0.4), "STORM LOCKDOWN", "NOW!", true, "PROTECTS CREW FROM STORM", "LOCK DOWN", true,
					func() -> void:
						close_dashboard()
						lockdown_requested.emit()
				)
			var max_sh := (GameState.shield >= Rules.max_value("shield"))
			_add_action_row("🛡️", Color(0.75, 0.5, 1.0), "UPGRADE SHIELD", "LVL %d/%d" % [GameState.shield, Rules.max_value("shield")], max_sh, "BLOCKS MORE STORM DAMAGE", "UPGRADE", "upgrade_shield", null)

		"comms_room":
			_add_action_row("📡", Color(0.45, 0.75, 1.0), "STORM FORECAST", "2d REPLY", false, "WARNS BEFORE BIG STORMS", "SEND", "forecast", null)
			_add_action_row("💬", Color(0.75, 0.6, 1.0), "MISSION ADVICE", "2d REPLY", false, "TIPS FROM EARTH CONTROL", "SEND", "advice", null)
			_add_action_row("📦", Color(0.4, 0.92, 0.5), "FOOD SUPPLY POD", "3d DROP", false, "DROPS A CRATE OF FOOD", "SEND", "resupply", "food")
			_add_action_row("📦", Color(0.35, 0.85, 1.0), "OXYGEN SUPPLY POD", "3d DROP", false, "DROPS AN OXYGEN TANK", "SEND", "resupply", "oxygen")
			_add_action_row("📦", Color(0.45, 0.68, 1.0), "WATER SUPPLY POD", "3d DROP", false, "DROPS CLEAN WATER", "SEND", "resupply", "water")


func _add_header_col(title: String, min_w: float) -> void:
	var lbl := UiKit.label(title, 11, UiKit.COLOR_MUTED, false)
	lbl.custom_minimum_size = Vector2(min_w, 20)
	table_headers.add_child(lbl)


func _add_action_row(
	icon_txt: String,
	col: Color,
	title: String,
	status_txt: String,
	is_active: bool,
	effect_txt: String,
	btn_txt: String,
	action_id: String,
	param: Variant
) -> void:
	var check := GameState.can_try_action(action_id, param)
	var ok := bool(check.get("ok", false))
	var final_btn := "ACTIVE" if is_active else btn_txt
	_add_table_row(
		icon_txt, col, title, status_txt, is_active,
		effect_txt if ok or is_active else String(check.get("reason", "")).to_upper(),
		final_btn, ok,
		func() -> void: GameState.try_action(action_id, param)
	)


func _add_table_row(
	icon_txt: String,
	col: Color,
	title: String,
	status_txt: String,
	is_active: bool,
	effect_txt: String,
	btn_txt: String,
	enabled: bool,
	callback: Callable
) -> void:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_ROW, UiKit.COLOR_BORDER_DIM, 8, 4, 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	strip.add_child(row)

	# 1. Icon + Name (220px)
	var name_box := HBoxContainer.new()
	name_box.custom_minimum_size = Vector2(220, 0)
	name_box.add_theme_constant_override("separation", 8)
	var ic := UiKit.label(icon_txt, 15, col, false)
	ic.custom_minimum_size = Vector2(22, 0)
	name_box.add_child(ic)
	name_box.add_child(UiKit.label(title, 13, UiKit.COLOR_TEXT, false))
	row.add_child(name_box)

	# 2. Setting pill (90px)
	var stat_pill := PanelContainer.new()
	stat_pill.custom_minimum_size = Vector2(90, 26)
	stat_pill.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_BG_DEEP, UiKit.COLOR_BORDER_DIM, 6, 4, 1))
	var slbl := UiKit.label(status_txt, 11, UiKit.COLOR_TEXT, false)
	slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_pill.add_child(slbl)
	row.add_child(stat_pill)

	# 3. Toggle indicator (70px)
	var tog := UiKit.label("──●" if is_active else "●──", 14, UiKit.COLOR_GOLD if is_active else UiKit.COLOR_MUTED, false)
	tog.custom_minimum_size = Vector2(70, 0)
	tog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(tog)

	# 4. Effect + crystal icon (220px)
	var eff_lbl := UiKit.label("◆ " + effect_txt, 12, UiKit.COLOR_ACCENT if enabled else UiKit.COLOR_MUTED, false)
	eff_lbl.custom_minimum_size = Vector2(220, 0)
	eff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(eff_lbl)

	# 5. Golden CTA Button (100px)
	var btn := UiKit.gold_button(btn_txt, 12, Vector2(98, 30))
	btn.disabled = not enabled
	btn.pressed.connect(callback)
	row.add_child(btn)

	rows_vbox.add_child(strip)
