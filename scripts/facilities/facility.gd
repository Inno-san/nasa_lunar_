extends Area2D
## Interactive Lunar Base Facility (Area2D + Solid Console Core + Press E / Click Prompt).
## Emits interaction_requested(facility_id) when triggered via E key or mouse/touch click.

signal interaction_requested(facility_id: String)
signal facility_clicked(facility: Area2D)

@export var facility_id: String = "power_station"
@export var facility_title: String = "Power Station"
@export var facility_subtitle: String = "Solar & Battery"
@export var facility_color: Color = Color(0.95, 0.72, 0.18, 1.0)

var astronaut_in_range: bool = false
var mouse_hovered: bool = false

@onready var box_fill: ColorRect = $Visuals/ConsoleFill
@onready var title_label: Label = $Visuals/TitleLabel
@onready var subtitle_label: Label = $Visuals/SubtitleLabel
@onready var prompt_button: Button = $PromptButton


func _ready() -> void:
	input_pickable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	prompt_button.pressed.connect(_on_prompt_button_pressed)
	_apply_visuals()
	_update_prompt()


func _apply_visuals() -> void:
	if box_fill != null:
		box_fill.color = facility_color
	if title_label != null:
		title_label.text = facility_title
	if subtitle_label != null:
		subtitle_label.text = facility_subtitle
	if prompt_button != null:
		prompt_button.text = "Press [E] or Click: " + facility_title


func _update_prompt() -> void:
	if prompt_button == null:
		return
	prompt_button.visible = astronaut_in_range or mouse_hovered
	if astronaut_in_range:
		prompt_button.text = "Press [E] or Click: " + facility_title
		prompt_button.modulate = Color(1.0, 0.96, 0.75, 1.0)
	else:
		prompt_button.text = "Click to Walk & Open: " + facility_title
		prompt_button.modulate = Color(0.85, 0.92, 1.0, 0.95)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("astronaut"):
		astronaut_in_range = true
		if body.has_method("register_nearby_facility"):
			body.register_nearby_facility(self)
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("astronaut"):
		astronaut_in_range = false
		if body.has_method("unregister_nearby_facility"):
			body.unregister_nearby_facility(self)
		_update_prompt()


func _on_mouse_entered() -> void:
	mouse_hovered = true
	_update_prompt()


func _on_mouse_exited() -> void:
	mouse_hovered = false
	_update_prompt()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_click()
		get_viewport().set_input_as_handled()


func _on_prompt_button_pressed() -> void:
	_handle_click()


func _handle_click() -> void:
	if astronaut_in_range:
		request_interaction()
	else:
		facility_clicked.emit(self)


func request_interaction() -> void:
	interaction_requested.emit(facility_id)

