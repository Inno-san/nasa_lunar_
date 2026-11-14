extends CharacterBody2D

const CHAR_CENTER_OFFSET_X := 2.5
const PET_CELL_OFFSET := Vector2(34.8, 8.9)
const PET_FOLLOW_OFFSET := Vector2(32.0, -24.0) # 40 px distance behind and above the player
const PET_LERP_SPEED := 6.0
const PET_BOB_SPEED := 4.0
const PET_BOB_AMPLITUDE := 3.5

@export var walk_speed: float = 240.0

var touch_direction: Vector2 = Vector2.ZERO
var movement_locked: bool = false

var nearby_facilities: Array[Area2D] = []
var has_click_target: bool = false
var click_target_pos: Vector2 = Vector2.ZERO
var pending_facility: Area2D = null
var facing_left: bool = false

var _stuck_timer: float = 0.0
var _was_moving: bool = false
var _bob_time: float = 0.0

@onready var walk_audio: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D")
@onready var pet_follower: Node2D = get_node_or_null("PetFollower")
@onready var pet_sprite: AnimatedSprite2D = get_node_or_null("PetFollower/AnimatedSprite2D")


func _ready() -> void:
	if anim_sprite != null:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play(&"idle")
	if pet_sprite != null:
		pet_sprite.play(&"default")
	if pet_follower != null:
		pet_follower.global_position = global_position + _get_pet_target_offset(0.0)


func _physics_process(delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		_update_walk_sound(false)
		_update_animation_and_pet(false, delta)
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
		_stuck_timer = 0.0
		velocity = input_dir * walk_speed
	elif has_click_target:
		var to_target := click_target_pos - global_position
		if (pending_facility != null and pending_facility in nearby_facilities) or to_target.length() <= 10.0:
			_interact_and_stop(pending_facility)
		else:
			velocity = to_target.normalized() * walk_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if has_click_target and get_slide_collision_count() > 0 and get_real_velocity().length() < 20.0:
		_stuck_timer += delta
		if _stuck_timer >= 0.25:
			has_click_target = false
			pending_facility = null
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	var is_moving := velocity.length() > 5.0 and get_real_velocity().length() > 5.0
	_update_walk_sound(is_moving)
	_update_animation_and_pet(is_moving, delta)


func _update_animation_and_pet(is_moving: bool, delta: float) -> void:
	if is_moving:
		if velocity.x < -1.0:
			facing_left = true
		elif velocity.x > 1.0:
			facing_left = false
		if anim_sprite != null:
			anim_sprite.flip_h = facing_left
			anim_sprite.position.x = -CHAR_CENTER_OFFSET_X if facing_left else CHAR_CENTER_OFFSET_X
			if anim_sprite.animation != &"run" or not anim_sprite.is_playing():
				anim_sprite.play(&"run")
		_was_moving = true
		_bob_time = 0.0
	else:
		if _was_moving:
			_was_moving = false
			if anim_sprite != null:
				anim_sprite.play(&"connect")
		elif anim_sprite != null and not anim_sprite.is_playing() and anim_sprite.animation not in [&"connect", &"stop"]:
			anim_sprite.play(&"idle")
		_bob_time += delta

	if pet_follower != null:
		var bob_y := 0.0 if is_moving else sin(_bob_time * PET_BOB_SPEED) * PET_BOB_AMPLITUDE
		var target_pos := global_position + _get_pet_target_offset(bob_y)
		pet_follower.global_position = pet_follower.global_position.lerp(target_pos, clampf(PET_LERP_SPEED * delta, 0.0, 1.0))
	if pet_sprite != null:
		pet_sprite.flip_h = facing_left
		pet_sprite.position.x = -PET_CELL_OFFSET.x if facing_left else PET_CELL_OFFSET.x
		if not pet_sprite.is_playing():
			pet_sprite.play(&"default")


func _get_pet_target_offset(bob_y: float) -> Vector2:
	var behind_x := PET_FOLLOW_OFFSET.x if facing_left else -PET_FOLLOW_OFFSET.x
	return Vector2(behind_x, PET_FOLLOW_OFFSET.y + bob_y)


func _on_animation_finished() -> void:
	if anim_sprite == null or _was_moving:
		return
	if anim_sprite.animation == &"connect":
		anim_sprite.play(&"stop")
	elif anim_sprite.animation == &"stop":
		anim_sprite.play(&"idle")


func _update_walk_sound(is_moving: bool) -> void:
	if walk_audio == null:
		return
	if is_moving and not movement_locked and not AudioManager.muted:
		if not walk_audio.playing:
			walk_audio.play()
	else:
		if walk_audio.playing:
			walk_audio.stop()


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
		_interact_and_stop(facility)


func unregister_nearby_facility(facility: Area2D) -> void:
	nearby_facilities.erase(facility)


func walk_to_point(world_pos: Vector2, target_facility: Area2D = null) -> void:
	if movement_locked:
		return
	if target_facility != null and target_facility in nearby_facilities:
		_interact_and_stop(target_facility)
		return
	click_target_pos = world_pos
	pending_facility = target_facility
	has_click_target = true
	_stuck_timer = 0.0


func _interact_and_stop(facility: Area2D = null) -> void:
	has_click_target = false
	pending_facility = null
	velocity = Vector2.ZERO
	if facility != null:
		facility.request_interaction()
