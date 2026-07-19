extends SceneTree

func _init():
	var main_scene = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	
	if main_scene.has_method("start_game"):
		main_scene.start_game()
	
	var ai_train = main_scene.get_node("Path3D_2").get_child(1) # PathFollow3D is 0, so Train is 1? Or CSGPolygon?
	
	# Let's just find the AI train by iterating Path3D_2 children
	var path2 = main_scene.get_node("Path3D_2")
	for c in path2.get_children():
		if c.has_method("_handle_input") and not c.is_player_controlled:
			ai_train = c
			break
			
	if not ai_train:
		print("AI Train not found!")
		quit()
		return
		
	# Move AI train to An Phu station manually
	ai_train.train_progress = 4800.0
	ai_train.force_position_update(4800.0)
	
	print("Starting simulation...")
	for i in range(4000): # simulate frames
		main_scene._process(0.016)
		for c in path2.get_children():
			if c.has_method("_process"):
				c._process(0.016)
			if c.has_method("_physics_process"):
				c._physics_process(0.016)
				
		if i % 1000 == 0:
			print("Frame ", i, ": speed=", ai_train.current_speed, " throttle=", ai_train.current_throttle, " doors=", ai_train.doors_open, " prog=", ai_train.train_progress, " timer=", ai_train.ai_timer_in_game_minutes)
			
	quit()
