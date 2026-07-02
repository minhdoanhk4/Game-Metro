extends Node3D

@onready var path_follow_1 = $Path3D_1/PathFollow3D
@onready var hud = $HUD
@onready var camera_drone = $Camera_Drone

var train_instance: Node = null
var ai_train_instance: Node = null

var train_scene_resource: PackedScene = null
var spawn_timer: float = 0.0
var next_spawn_interval: float = 45.0 # 8 to 10 game minutes = 40 to 50 real seconds
var original_env: Environment = null
var is_map_lighting_active: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_spawn_interval = randf_range(40.0, 50.0)
	hud.main_menu_play.connect(start_game)
	
	if has_node("WorldEnvironment"):
		var we = $WorldEnvironment
		if we.environment:
			original_env = we.environment.duplicate()
	
	# Instantiate and attach SceneryManager to generate pillars and lights
	var sm = Node.new()
	sm.name = "SceneryManager"
	sm.set_script(preload("res://Scripts/SceneryManager.gd"))
	add_child(sm)
	

	
	if not GameManager.skip_menu:
		call_deferred("_spawn_preview_train", 0)

var preview_train_instance: Node = null
var menu_camera: Camera3D = null

func _spawn_preview_train(index: int):
	if is_instance_valid(preview_train_instance):
		preview_train_instance.queue_free()
		preview_train_instance = null
		
	var path = GameManager.train_list[index]["path"]
	var res = load(path)
	if res:
		preview_train_instance = res.instantiate()
		preview_train_instance.is_preview = true
		preview_train_instance.is_player_controlled = false
		preview_train_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		$Path3D_1.add_child(preview_train_instance)
		call_deferred("_setup_preview_camera_and_position", preview_train_instance)

func _setup_preview_camera_and_position(train_instance: Node):
	if not is_instance_valid(train_instance) or not train_instance.is_inside_tree():
		return
		
	await get_tree().process_frame
	if not is_instance_valid(train_instance) or not train_instance.is_inside_tree():
		return
		
	var station = null
	for s in get_tree().get_nodes_in_group("stations"):
		if s.station_name.to_upper() == "BEN THANH":
			station = s
			break
	if station:
		var local_pos = $Path3D_1.to_local(station.global_transform.origin)
		var offset = $Path3D_1.curve.get_closest_offset(local_pos)
		if offset < 10.0:
			offset = 100.0
		train_instance.train_progress = offset
		if train_instance.has_method("force_position_update"):
			train_instance.force_position_update(offset)
		else:
			train_instance.follow1.progress = offset
			train_instance.follow2.progress = offset - 21.0
			train_instance.follow3.progress = offset - 42.0
			train_instance.car1.global_transform = train_instance.follow1.global_transform * Transform3D(Basis(), Vector3(0, 0.5, 0))
			train_instance.car2.global_transform = train_instance.follow2.global_transform * Transform3D(Basis(), Vector3(0, 0.5, 0))
			train_instance.car3.global_transform = train_instance.follow3.global_transform * Transform3D(Basis().rotated(Vector3.UP, PI), Vector3(0, 0.5, 0))
		
		train_instance.doors_open = true
		
		if not is_instance_valid(menu_camera):
			menu_camera = Camera3D.new()
			menu_camera.name = "MenuCamera"
			menu_camera.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(menu_camera)
			
		var nose_pos = train_instance.car1.global_transform.origin
		var forward_dir = -train_instance.car1.global_transform.basis.z.normalized()
		menu_camera.global_position = nose_pos + forward_dir * 13.0 + Vector3(4.5, 1.5, 0.0)
		menu_camera.look_at(nose_pos + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		menu_camera.make_current()

func start_game():
	if is_instance_valid(preview_train_instance):
		preview_train_instance.queue_free()
		preview_train_instance = null
	if is_instance_valid(menu_camera):
		menu_camera.queue_free()
		menu_camera = null
		
	var pm = Node.new()
	pm.name = "PassengerManager"
	pm.set_script(preload("res://Scripts/PassengerManager.gd"))
	add_child(pm)
		
	var train_path = GameManager.get_current_train_path()
	train_scene_resource = load(train_path)
	if train_scene_resource:
		_spawn_train()

func _spawn_train():
	train_instance = train_scene_resource.instantiate()
	$Path3D_1.add_child(train_instance)

func _spawn_ai_train():
	var ai_path = GameManager.get_ai_train_path()
	var ai_res = load(ai_path)
	if ai_res:
		var ai_train = ai_res.instantiate()
		ai_train.is_player_controlled = false
		ai_train.direction_forward = false
		$Path3D_2.add_child(ai_train)

func set_map_lighting_active(active: bool):
	is_map_lighting_active = active
	_update_lighting_and_env()

func _process(delta):
	# Spawning and camera drone tracking should only happen when not paused
	if not get_tree().paused:
		if train_scene_resource:
			spawn_timer += delta
			if spawn_timer >= next_spawn_interval:
				spawn_timer = 0.0
				next_spawn_interval = randf_range(40.0, 50.0)
				_spawn_ai_train()
				
		if train_instance and camera_drone:
			var car1 = train_instance.get_node_or_null("Car1")
			if car1:
				# Drone camera tracks the train from above
				var target_pos = car1.global_position + Vector3(0, 30, 0)
				camera_drone.global_position = camera_drone.global_position.lerp(target_pos, delta * 2.0)
				# Ensure it looks at the train
				camera_drone.look_at(car1.global_position, Vector3.FORWARD)

	# Lighting updates run always, even when paused (allowing map daylight mode)
	_update_lighting_and_env()

func _update_lighting_and_env():
	var is_underground = false
	var cam = get_viewport().get_camera_3d()
	if cam:
		is_underground = cam.global_position.y < -5.0

	# Map view and menu get forced bright daylight lighting
	if is_map_lighting_active or is_instance_valid(menu_camera):
		if has_node("DirectionalLight3D"):
			var light = $DirectionalLight3D
			light.visible = true
			light.light_energy = 1.2
			light.rotation.x = deg_to_rad(-60.0) # noon-ish overhead light
			light.rotation.y = deg_to_rad(-45.0)
			
		if has_node("WorldEnvironment") and original_env:
			var we = $WorldEnvironment
			we.environment.background_mode = original_env.background_mode
			we.environment.background_color = original_env.background_color
			we.environment.ambient_light_source = original_env.ambient_light_source
			we.environment.ambient_light_color = original_env.ambient_light_color
			we.environment.ambient_light_energy = original_env.ambient_light_energy
		return

	# Update directional light based on time and underground state
	if has_node("DirectionalLight3D"):
		var light = $DirectionalLight3D
		if is_underground:
			light.visible = false
			light.light_energy = 0.0
		else:
			light.visible = true
			var day_progress = (GameManager.time_hours - 6.0) / 12.0
			var angle = lerp(0.0, -PI, clamp(day_progress, 0.0, 1.0))
			light.rotation.x = angle
			light.rotation.y = deg_to_rad(-45.0)
			
			if GameManager.time_hours > 18.0 or GameManager.time_hours < 6.0:
				light.light_energy = 0.05
			else:
				light.light_energy = 1.0

	# Update environment based on underground state
	if has_node("WorldEnvironment") and original_env:
		var we = $WorldEnvironment
		if is_underground:
			we.environment.background_mode = 1 # BG_COLOR
			we.environment.background_color = Color.BLACK
			we.environment.ambient_light_source = 2 # AMBIENT_SOURCE_COLOR
			we.environment.ambient_light_color = Color.BLACK
			we.environment.ambient_light_energy = 0.0
		else:
			we.environment.background_mode = original_env.background_mode
			we.environment.background_color = original_env.background_color
			we.environment.ambient_light_source = original_env.ambient_light_source
			we.environment.ambient_light_color = original_env.ambient_light_color
			we.environment.ambient_light_energy = original_env.ambient_light_energy

func _on_station_area_entered(_area):
	pass

func process_station_stop(station_name: String):
	# Station stop rewards are handled dynamically by PassengerManager
	pass
