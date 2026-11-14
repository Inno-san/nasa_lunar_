extends Node2D
## Main LunarBase scene wiring Astronaut, 5 Facilities, HUD, DashboardManager,
## StormOverlay, DaySummary, EventPopup, and EndScreen.

@onready var astronaut: CharacterBody2D = $Astronaut
@onready var facilities_root: Node2D = $Facilities
@onready var shelter_facility: Area2D = $Facilities/RadiationShelter
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var hud: Control = $CanvasLayer/HUD
@onready var dashboard_manager: Control = $CanvasLayer/DashboardManager

var storm_overlay: StormOverlay
var day_summary: DaySummary
var event_popup: EventPopup
var end_screen: EndScreen


func _ready() -> void:
	for child in facilities_root.get_children():
		if child.has_signal("interaction_requested"):
			child.interaction_requested.connect(_on_facility_interaction_requested)
		if child.has_signal("facility_clicked"):
			child.facility_clicked.connect(_on_facility_clicked)

	hud.touch_move_changed.connect(_on_touch_move_changed)
	hud.interact_pressed.connect(_on_hud_interact_pressed)
	dashboard_manager.dashboard_visibility_changed.connect(_func_sync_lock)
	dashboard_manager.lockdown_requested.connect(_on_lockdown_requested)

	storm_overlay = StormOverlay.new()
	storm_overlay.in_shelter = func() -> bool:
		return shelter_facility != null and shelter_facility.astronaut_in_range
	storm_overlay.finished.connect(_on_storm_finished)
	canvas_layer.add_child(storm_overlay)

	day_summary = DaySummary.new()
	day_summary.continue_pressed.connect(_on_day_summary_continue)
	canvas_layer.add_child(day_summary)

	event_popup = EventPopup.new()
	event_popup.answered.connect(_on_event_answered)
	canvas_layer.add_child(event_popup)

	end_screen = EndScreen.new()
	end_screen.play_again_requested.connect(_on_play_again)
	end_screen.main_menu_requested.connect(_on_main_menu)
	canvas_layer.add_child(end_screen)

	GameState.storm_started.connect(_on_storm_started)
	GameState.day_ended.connect(_on_day_ended)
	_sync_astronaut_lock()


func _unhandled_input(event: InputEvent) -> void:
	if _is_any_modal_open():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_world_click(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_handle_world_click(get_global_mouse_position())


func _handle_world_click(click_pos: Vector2) -> void:
	for child in facilities_root.get_children():
		if child is Area2D:
			var rel: Vector2 = click_pos - child.global_position
			if absf(rel.x) <= 110.0 and rel.y >= -140.0 and rel.y <= 80.0:
				if child.has_method("_handle_click"):
					child._handle_click()
					return
	astronaut.walk_to_point(click_pos, null)


func _is_any_modal_open() -> bool:
	return (
		dashboard_manager.visible
		or (day_summary != null and day_summary.is_open())
		or (event_popup != null and event_popup.is_open())
		or (end_screen != null and end_screen.is_open())
		or (storm_overlay != null and storm_overlay.is_active() and not storm_overlay.is_counting())
	)


func _func_sync_lock(_open: bool) -> void:
	_sync_astronaut_lock()


func _sync_astronaut_lock() -> void:
	if astronaut != null:
		astronaut.movement_locked = _is_any_modal_open()


func _on_facility_interaction_requested(facility_id: String) -> void:
	dashboard_manager.open_dashboard(facility_id)
	_sync_astronaut_lock()


func _on_facility_clicked(facility: Area2D) -> void:
	if _is_any_modal_open():
		return
	astronaut.walk_to_point(facility.global_position, facility)


func _on_touch_move_changed(direction: Vector2) -> void:
	astronaut.touch_direction = direction


func _on_hud_interact_pressed() -> void:
	if dashboard_manager.visible:
		dashboard_manager.close_dashboard()
		return
	if astronaut != null and not astronaut.nearby_facilities.is_empty():
		astronaut.interact_with_nearest()
	else:
		var fallback_id: String = (
			dashboard_manager.current_facility_id
			if dashboard_manager.current_facility_id != ""
			else "power_station"
		)
		dashboard_manager.open_dashboard(fallback_id)
		_sync_astronaut_lock()


func _on_storm_started(info: Dictionary) -> void:
	dashboard_manager.close_dashboard()
	storm_overlay.begin(info)
	_sync_astronaut_lock()


func _on_lockdown_requested() -> void:
	if storm_overlay != null and storm_overlay.is_counting():
		storm_overlay.lockdown_now()


func _on_storm_finished(reached_shelter: bool) -> void:
	dashboard_manager.close_dashboard()
	GameState.resolve_storm(reached_shelter)
	_sync_astronaut_lock()


func _on_day_ended(report: Dictionary) -> void:
	dashboard_manager.close_dashboard()
	day_summary.show_report(report)
	_sync_astronaut_lock()


func _on_day_summary_continue() -> void:
	if GameState.game_over:
		end_screen.show_end_screen()
		_sync_astronaut_lock()
		return
	_show_next_pending_event()


func _show_next_pending_event() -> void:
	if not GameState.pending_events.is_empty():
		var next_ev: Dictionary = GameState.pending_events.pop_front()
		event_popup.show_event(next_ev)
	_sync_astronaut_lock()


func _on_event_answered() -> void:
	_show_next_pending_event()


func _on_play_again() -> void:
	GameState.reset_game()
	astronaut.position = Vector2(364, 579)
	_sync_astronaut_lock()


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
