extends CharacterBody2D
## Top-down 2D Astronaut controller.
## Supports WASD/Arrow keys, on-screen touch D-pad, cursor click-to-move/click-facility, and E to interact.

@export var walk_speed: float = 240.0

var touch_direction: Vector2 = Vector2.ZERO
var movement_locked: bool = false

var nearby_facilities: Array[Area2D] = []
var has_click_target: bool = false
var click_target_pos: Vector2 = Vector2.ZERO
var pending_facility: Area2D = null


func _physics_process(_delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var key_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input_dir := key_dir + touch_direction
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	if input_dir.length() > 0.05:
		# Manual keyboard/D-pad input cancels any cursor auto-walk target
		has_click_target = false
		pending_facility = null
		velocity = input_dir * walk_speed
	elif has_click_target:
		var to_target := click_target_pos - global_position
		if pending_facility != null and pending_facility in nearby_facilities:
			has_click_target = false
			velocity = Vector2.ZERO
			var fac := pending_facility
			pending_facility = null
			fac.request_interaction()
		elif to_target.length() <= 10.0:
			has_click_target = false
			velocity = Vector2.ZERO
			if pending_facility != null:
				var fac := pending_facility
				pending_facility = null
				fac.request_interaction()
		else:
			velocity = to_target.normalized() * walk_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if movement_locked:
		return
	if event.is_action_pressed("interact"):
		interact_with_nearest()
		get_viewport().set_input_as_handled()


func interact_with_nearest() -> bool:
	var active := get_nearest_facility()
	if active != null and active.has_method("request_interaction"):
		active.request_interaction()
		return true
	return false


func get_nearest_facility() -> Area2D:
	if nearby_facilities.is_empty():
		return null
	var best: Area2D = null
	var best_dist := INF
	for fac in nearby_facilities:
		if not is_instance_valid(fac):
			continue
		var d := global_position.distance_squared_to(fac.global_position)
		if d < best_dist:
			best_dist = d
			best = fac
	return best


func register_nearby_facility(facility: Area2D) -> void:
	if facility not in nearby_facilities:
		nearby_facilities.append(facility)
	if pending_facility == facility:
		has_click_target = false
		pending_facility = null
		facility.request_interaction()


func unregister_nearby_facility(facility: Area2D) -> void:
	nearby_facilities.erase(facility)


func walk_to_point(world_pos: Vector2, target_facility: Area2D = null) -> void:
	if movement_locked:
		return
	if target_facility != null and target_facility in nearby_facilities:
		has_click_target = false
		pending_facility = null
		target_facility.request_interaction()
		return
	click_target_pos = world_pos
	pending_facility = target_facility
	has_click_target = true

