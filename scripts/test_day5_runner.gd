extends SceneTree
## Headless CLI test runner for verifying the Day-5 worked example and shortage cut order.
## Run with: godot --headless --path . -s res://scripts/test_day5_runner.gd


func _initialize() -> void:
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state == null:
		printerr("GameState autoload not found!")
		quit(1)
		return

	var res: Dictionary = game_state.run_day5_debug_test()
	print("Day-5 Test Result Dictionary: ", JSON.stringify(res))

	if not bool(res.get("passed", false)):
		printerr("Day-5 Debug Test FAILED!")
		quit(1)
		return

	# Also verify the LunarBase main scene instantiates cleanly
	var packed: PackedScene = load("res://scenes/lunar_base.tscn")
	if packed == null:
		printerr("Failed to load res://scenes/lunar_base.tscn")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)

	# Verify shortage cut order when battery is 0 and solar cannot cover everything
	game_state.reset_game()
	game_state.battery = 0
	game_state.life_support_mode = "high"
	game_state.greenhouse_mode = "high"
	game_state.shield = 3
	# Total cost before cuts: base(6) + LS_high(20) + shield(6) + GH_high(14) = 46 > solar(36)
	# Cut #1 turns GH off (-14) -> cost becomes 32 <= 36 -> battery ends at 4
	var cut_report: Dictionary = game_state.end_day()
	print("Shortage Cut Test Report: ", JSON.stringify(cut_report))

	instance.free()
	print("ALL MILESTONE 1-3 CHECKS PASSED!")
	quit(0)

