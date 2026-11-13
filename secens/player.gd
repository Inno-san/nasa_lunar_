extends CharacterBody2D
var direction:Vector2
@export var speed:= 10000

func _physics_process(delta: float) -> void:
	getinput()
	velocity = direction*speed*delta
	move_and_slide()


func getinput():
	#player movement direction
	direction = Input.get_vector("move_left","move_right","move_up","move_down")
	#plalyer_action
	if Input.is_action_just_pressed("action_button"):
		print("potato")
	
