class_name StormOverlay
extends Control
## Storm phase screens: (1) a card with the linked NASA record, (2) a countdown banner
## with a one-click button to rush into the Radiation Shelter and lock down.

signal countdown_started
signal finished(reached_shelter: bool)

var in_shelter: Callable = func() -> bool: return false

var _active: bool = false
var _counting: bool = false
var _time_left: float = 0.0
var _total: float = 1.0
var _intro: Control
var _banner: PanelContainer
var _time_label: Label
var _bar: ProgressBar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_banner()
	_banner.visible = false


func is_active() -> bool:
	return _active


func is_counting() -> bool:
	return _counting


func begin(info: Dictionary) -> void:
	_active = true
	_counting = false
	_total = maxf(1.0, float(info.get("seconds", 10.0)))
	_time_left = _total
	AudioManager.start_alarm()

	var parts := UiKit.make_overlay(820.0)
	_intro = parts[0]
	var box: VBoxContainer = parts[1]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiKit.label("🚨 SOLAR STORM ALERT! (Day %d)" % int(info.get("day", 0)), UiKit.FONT_TITLE, UiKit.COLOR_BAD, false))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(Explain.make_button("solar_storm"))
	head.add_child(Explain.make_button("radiation"))
	box.add_child(head)
	var warned := bool(info.get("warned", false))
	box.add_child(UiKit.label(
		"Mission Control warned you about this storm, so you have extra time!" if warned else "Surprise storm! Get to the purple Radiation Shelter fast!",
		UiKit.FONT_BODY, UiKit.COLOR_WARN))
	box.add_child(FactCard.make_storm(info))
	box.add_child(UiKit.label(
		"Run to the purple Radiation Shelter (bottom middle) or click the big button on the timer to hide inside!",
		UiKit.FONT_BODY))
	var go := UiKit.button("Start Timer & Run to Shelter! ▶", UiKit.FONT_TITLE, Vector2(0, 60))
	go.pressed.connect(_start_countdown)
	box.add_child(go)
	add_child(_intro)
	go.grab_focus()


func _start_countdown() -> void:
	if _intro != null and is_instance_valid(_intro):
		_intro.queue_free()
	_intro = null
	_counting = true
	_banner.visible = true
	_update_banner()
	countdown_started.emit()


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -350.0
	_banner.offset_right = 350.0
	_banner.offset_top = 118.0
	_banner.offset_bottom = 250.0
	_banner.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.35, 0.05, 0.05, 0.96), Color(1, 0.7, 0.4, 1), 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_banner.add_child(box)
	_time_label = UiKit.label("", UiKit.FONT_TITLE, UiKit.COLOR_TEXT, false)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_time_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	box.add_child(_bar)
	var rush_btn := UiKit.button("🏃 RUSH TO RADIATION SHELTER & LOCK DOWN NOW!", 18, Vector2(0, 46))
	rush_btn.pressed.connect(lockdown_now)
	box.add_child(rush_btn)
	add_child(_banner)


func _update_banner() -> void:
	_time_label.text = "SOLAR STORM!  %d seconds left" % ceili(_time_left)
	_bar.max_value = _total
	_bar.value = _time_left


func _process(delta: float) -> void:
	if not _counting:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish(bool(in_shelter.call()))
		return
	_update_banner()


func lockdown_now() -> void:
	if _counting:
		_finish(true)


func _finish(reached_shelter: bool) -> void:
	_counting = false
	_active = false
	_banner.visible = false
	AudioManager.stop_alarm()
	finished.emit(reached_shelter)
