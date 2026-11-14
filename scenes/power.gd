extends Sprite2D
var height :=10.0
func _process(_delta: float) -> void:
	hover_up()
func hover_up():
	var tween = create_tween()
	tween.tween_property(self,"position",Vector2(0,-100),0.25).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(hover_down)
func hover_down():
	var tween = create_tween()
	tween.tween_property(self,"position",Vector2(0,-50),0.5).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(hover_up)
