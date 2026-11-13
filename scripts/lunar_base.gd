extends Node2D
## Main LunarBase scene wiring Astronaut, 5 Facilities, HUD, and DashboardManager.

@onready var astronaut: CharacterBody2D = $Astronaut
@onready var facilities_root: Node2D = $Facilities
@onready var hud: Control = $CanvasLayer/HUD
@onready var dashboard_manager: Control = $CanvasLayer/DashboardManager


func _ready() -> void:
	for child in facilities_root.get_children():
		if child.has_signal("interaction_requested"):
			child.interaction_requested.connect(_on_facility_interaction_requested)
		if child.has_signal("facility_clicked"):
			child.facility_clicked.connect(_on_facility_clicked)

	hud.touch_move_changed.connect(_on_touch_move_changed)
	hud.interact_pressed.connect(_on_hud_interact_pressed)
	dashboard_manager.dashboard_visibility_changed.connect(_on_dashboard_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if dashboard_manager.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = get_global_mouse_position()
		# Walk if click is inside the habitat floor area
		if click_pos.x >= 70.0 and click_pos.x <= 1210.0 and click_pos.y >= 105.0 and click_pos.y <= 600.0:
			astronaut.walk_to_point(click_pos, null)


func _on_facility_interaction_requested(facility_id: String) -> void:
	dashboard_manager.open_dashboard(facility_id)


func _on_facility_clicked(facility: Area2D) -> void:
	astronaut.walk_to_point(facility.global_position, facility)


func _on_touch_move_changed(direction: Vector2) -> void:
	astronaut.touch_direction = direction


func _on_hud_interact_pressed() -> void:
	if dashboard_manager.visible:
		dashboard_manager.close_dashboard()
	else:
		astronaut.interact_with_nearest()


func _on_dashboard_visibility_changed(is_open: bool) -> void:
	astronaut.movement_locked = is_open

