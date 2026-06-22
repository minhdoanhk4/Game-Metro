extends Node3D
class_name Train

signal doors_opened
signal doors_closed
signal horn_blown

@export var is_player_controlled: bool = true
@export var max_speed: float = 100.0 # km/h
@export var acceleration: float = 10.0
@export var braking_force: float = 20.0
@export var friction: float = 2.0

var current_speed: float = 0.0 # km/h
var current_throttle: float = 0.0 # 0.0 to 1.0 (0 is brake)
var doors_open: bool = false
var global_door_progress_left: float = 0.0
var global_door_progress_right: float = 0.0
var approach_speed_limit: float = INF # set by Station to cap speed in zone
var auto_stop_enabled: bool = true
var current_station: Node = null

var cached_stations: Array = []
var cached_trains: Array = []

func _get_stations() -> Array:
	if cached_stations.is_empty():
		cached_stations = get_tree().get_nodes_in_group("stations")
	return cached_stations

func _get_trains() -> Array:
	if cached_trains.is_empty():
		cached_trains = get_tree().get_nodes_in_group("train")
	return cached_trains
var cameras: Array[Camera3D] = []
var current_camera_index: int = 0

@onready var path_node: Path3D = get_parent() as Path3D
var cars: Array[Node3D] = []
var follows: Array[PathFollow3D] = []
var follow1: PathFollow3D
var follow2: PathFollow3D
var follow3: PathFollow3D
var car1: Node3D
var car2: Node3D
var car3: Node3D
var train_progress: float = 0.0
var direction_forward: bool = true

var running_audio: AudioStreamPlayer3D
var doors_audio: AudioStreamPlayer3D
var horn_audio: AudioStreamPlayer3D
var approach_audio: AudioStreamPlayer3D
var depart_audio: AudioStreamPlayer3D
var bridge_audio: AudioStreamPlayer3D
var stopping_audio: AudioStreamPlayer3D

var has_played_approach_sound: bool = false
var has_played_depart_sound: bool = true
var has_played_stop_sound: bool = true
var bridge_sound_cooldown: float = 0.0
var prev_y: float = 0.0
var prev_yaw: float = 0.0
var is_preview: bool = false





func _ready():
	if not is_preview:
		add_to_group("train")
	if not path_node:
		push_warning("Train must be a child of Path3D to move along tracks!")
		return
		
	# Dynamically gather all cars
	var car_idx = 1
	while true:
		var car_node = get_node_or_null("Car" + str(car_idx))
		if car_node:
			cars.append(car_node)
			car_idx += 1
		else:
			break
			
	if cars.size() > 0:
		car1 = cars[0]
	if cars.size() > 1:
		car2 = cars[1]
	if cars.size() > 2:
		car3 = cars[cars.size() - 1]
		
	# Articulation Setup: Create followers dynamically to snake along the track
	for j in range(cars.size()):
		var follow = PathFollow3D.new()
		follows.append(follow)
		path_node.call_deferred("add_child", follow)
		
	# Assign first/last followers for compatibility
	if follows.size() > 0: follow1 = follows[0]
	if follows.size() > 1: follow2 = follows[1]
	if follows.size() > 2: follow3 = follows[follows.size() - 1]
	
	# Reparent CameraBoom to Car1 to follow it automatically
	if has_node("CameraBoom") and car1:
		var boom = $CameraBoom
		remove_child(boom)
		car1.add_child(boom)
		boom.position = Vector3(0, 15, 69) # Maintain original relative distance
	
	# Reparent Hitbox to Car1
	if has_node("Hitbox"):
		var hitbox = $Hitbox
		if is_preview:
			hitbox.queue_free()
		else:
			remove_child(hitbox)
			if car1:
				car1.add_child(hitbox)
				hitbox.position = Vector3(0, 2, 21) # Center of the formation

	# Doors are now purely shader driven

	_setup_cameras()
	
	# Reset local Z offsets of the cars so they attach directly to followers
	for car in cars:
		car.position.z = 0
	
	# Make Cabin camera current by default
	if is_player_controlled and not is_preview:
		for i in range(cameras.size()):
			if cameras[i].name == "Cam_Cabin":
				current_camera_index = i
				cameras[i].make_current()
				break

	# Snap train to station at game start (deferred so Area3D groups are ready)
	if not is_preview:
		call_deferred("_start_at_station")
		_setup_audio()



func _setup_audio():
	# 1. Running sound (loops)
	running_audio = AudioStreamPlayer3D.new()
	running_audio.max_distance = 400.0
	running_audio.unit_size = 25.0
	car1.add_child(running_audio)
	
	var run_stream = null
	if ResourceLoader.exists("res://Assets/sound-of-tieng-tau-dang-chay.mp3"):
		run_stream = load("res://Assets/sound-of-tieng-tau-dang-chay.mp3")
	elif ResourceLoader.exists("res://Assets/wind_sound.wav"):
		run_stream = load("res://Assets/wind_sound.wav")
		
	if run_stream:
		if run_stream is AudioStreamWAV:
			run_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			run_stream.loop_begin = 0
			run_stream.loop_end = 0
		elif "loop" in run_stream:
			run_stream.loop = true
		running_audio.stream = run_stream
		running_audio.play()
		running_audio.volume_db = -80.0

	# 2. Approach sound
	approach_audio = AudioStreamPlayer3D.new()
	approach_audio.max_distance = 400.0
	approach_audio.unit_size = 20.0
	car1.add_child(approach_audio)
	if ResourceLoader.exists("res://Assets/sound-of-tieng-tau-cap-ben.mp3"):
		approach_audio.stream = load("res://Assets/sound-of-tieng-tau-cap-ben.mp3")
	elif ResourceLoader.exists("res://Assets/sound-of-train-approaching-platform.mp3"):
		approach_audio.stream = load("res://Assets/sound-of-train-approaching-platform.mp3")

	# 3. Depart sound
	depart_audio = AudioStreamPlayer3D.new()
	depart_audio.max_distance = 400.0
	depart_audio.unit_size = 20.0
	car1.add_child(depart_audio)
	if ResourceLoader.exists("res://Assets/sound-of-tieng-tau-khoi-hanh.mp3"):
		depart_audio.stream = load("res://Assets/sound-of-tieng-tau-khoi-hanh.mp3")
	elif ResourceLoader.exists("res://Assets/sound-of-train-leave-after-horn.mp3"):
		depart_audio.stream = load("res://Assets/sound-of-train-leave-after-horn.mp3")

	# 4. Bridge sound
	bridge_audio = AudioStreamPlayer3D.new()
	bridge_audio.max_distance = 400.0
	bridge_audio.unit_size = 20.0
	car1.add_child(bridge_audio)
	if ResourceLoader.exists("res://Assets/sound-of-train-arrive-on-brighd.mp3"):
		bridge_audio.stream = load("res://Assets/sound-of-train-arrive-on-brighd.mp3")

	# 5. Stopping sound
	stopping_audio = AudioStreamPlayer3D.new()
	stopping_audio.max_distance = 400.0
	stopping_audio.unit_size = 20.0
	car1.add_child(stopping_audio)
	if ResourceLoader.exists("res://Assets/sound-of-tau-dung-han.mp3"):
		stopping_audio.stream = load("res://Assets/sound-of-tau-dung-han.mp3")

	# 6. Doors sound
	doors_audio = AudioStreamPlayer3D.new()
	doors_audio.max_distance = 250.0
	doors_audio.unit_size = 15.0
	car1.add_child(doors_audio)
	if ResourceLoader.exists("res://Assets/sound-of-tieng-mo-cua-dong-cua.mp3"):
		doors_audio.stream = load("res://Assets/sound-of-tieng-mo-cua-dong-cua.mp3")
	elif ResourceLoader.exists("res://Assets/sound-of-train-open-door.mp3"):
		doors_audio.stream = load("res://Assets/sound-of-train-open-door.mp3")
	elif ResourceLoader.exists("res://Assets/doors_sound.wav"):
		doors_audio.stream = load("res://Assets/doors_sound.wav")

	# 7. Horn sound
	horn_audio = AudioStreamPlayer3D.new()
	horn_audio.max_distance = 600.0
	horn_audio.unit_size = 40.0
	car1.add_child(horn_audio)
	if ResourceLoader.exists("res://Assets/horn_sound.wav"):
		horn_audio.stream = load("res://Assets/horn_sound.wav")

func play_horn():
	if horn_audio and horn_audio.stream:
		horn_audio.play()
	horn_blown.emit()


func get_nearest_station() -> Node:
	var stations = _get_stations()
	var nearest_station = null
	var min_dist = INF
	if car1:
		for s in stations:
			var dist = (car1.global_transform.origin - s.global_transform.origin).length()
			if dist < min_dist:
				min_dist = dist
				nearest_station = s
	if min_dist < 100.0:
		return nearest_station
	return null


func _start_at_station():
	# Find the first station in the scene and snap the train to it
	var stations = _get_stations()
	if stations.is_empty() or not path_node:
		return

	var station = null
	var target_name = "BEN THANH" if direction_forward else "THU DUC"
	for s in stations:
		if s.station_name.to_upper() == target_name:
			station = s
			break
			
	if not station:
		station = stations[0]
		
	# Convert to local space for Curve3D
	var local_pos = path_node.to_local(station.global_transform.origin)
	var offset = path_node.curve.get_closest_offset(local_pos)
	
	# Fallback: if spawning at Ben Thanh but offset is wrongly 0
	if direction_forward and offset < 10.0 and local_pos.z >= -10.0:
		offset = 100.0
		
	train_progress = offset
	force_position_update(train_progress)

	# Start with doors open at the station
	doors_open = true
	print("Train spawned at station: ", station.station_name, " | progress: ", train_progress)

func force_position_update(offset: float):
	train_progress = offset
	if not path_node or follows.is_empty():
		return
	var total_length = path_node.curve.get_baked_length()
	if total_length > 0:
		for j in range(cars.size()):
			var progress_offset = -j * 21.0 if direction_forward else j * 21.0
			follows[j].progress = train_progress + progress_offset
			
			var is_last = (j == cars.size() - 1)
			var rot_y = 0.0
			if direction_forward:
				rot_y = PI if is_last else 0.0
			else:
				rot_y = 0.0 if is_last else PI
			var basis = Basis().rotated(Vector3.UP, rot_y)
			if j < cars.size() and j < follows.size():
				cars[j].global_transform = follows[j].global_transform * Transform3D(basis, Vector3(0, 0.5, 0))

func _setup_cameras():
	# CameraBoom's camera was moved to Car1 along with the Boom
	var cam_3rd = get_node_or_null("Car1/CameraBoom/Camera3D")
	if cam_3rd:
		cam_3rd.name = "Cam_ThirdPerson"
		cameras.append(cam_3rd)
	
	# Add local cameras to individual cars
	_add_camera("Cabin", car1, Vector3(0, 1.8, -8.0), Vector3(0, 0, 0))
	if cars.size() > 0:
		_add_camera("Car_1", car1, Vector3(0, 2.0, 6.0), Vector3(0, 0, 0))
	if cars.size() > 1:
		_add_camera("Car_2", car2, Vector3(0, 2.0, 0.0), Vector3(0, 0, 0))
	if cars.size() > 2:
		var last_idx = cars.size()
		_add_camera("Car_" + str(last_idx), car3, Vector3(0, 2.0, 0.0), Vector3(0, deg_to_rad(180), 0))
	_add_camera("Front", car1, Vector3(0, 1.0, -12.0), Vector3(0, 0, 0))
	_add_camera("Side", car1, Vector3(25, 2, 0), Vector3(0, deg_to_rad(90), 0))
	_add_camera("Isometric", car1, Vector3(30, 25, -10), Vector3(deg_to_rad(-35), deg_to_rad(135), 0))

func _add_camera(cname: String, target_car: Node, pos: Vector3, rot: Vector3):
	var cam = Camera3D.new()
	cam.name = "Cam_" + cname
	target_car.add_child(cam)
	cam.position = pos
	cam.rotation = rot
	cameras.append(cam)



func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H and is_player_controlled:
			play_horn()
		elif event.keycode == KEY_C and is_player_controlled: # Press C to switch camera
			if cameras.size() > 0:
				var next_idx = current_camera_index
				var attempts = 0
				var is_underground = car1.global_transform.origin.z < 2200.0
				
				while attempts < cameras.size():
					next_idx = (next_idx + 1) % cameras.size()
					var cam_name = cameras[next_idx].name
					var allowed = true
					
					if is_underground:
						# Restrict to inside/front/side cameras when underground (keeping Cam_Side allowed)
						if cam_name in ["Cam_ThirdPerson", "Cam_Isometric"]:
							allowed = false
							
					if allowed:
						current_camera_index = next_idx
						cameras[current_camera_index].make_current()
						
						var hud_node = get_tree().current_scene.get_node_or_null("HUD")
						break
					attempts += 1
	


func _process(delta):
	if is_preview:
		_animate_doors(delta)
		return

	_handle_input(delta)
	_update_physics(delta)
	_update_audio(delta)


	var is_underground = car1.global_transform.origin.z < 2200.0
	
	# Automatically switch camera to cabin if we enter underground with an disallowed camera
	if is_underground:
		var cur_cam_name = cameras[current_camera_index].name
		if cur_cam_name in ["Cam_ThirdPerson", "Cam_Isometric"]:
			# Force switch to Cabin
			for i in range(cameras.size()):
				if cameras[i].name == "Cam_Cabin":
					current_camera_index = i
					cameras[i].make_current()
					
					var hud_node = get_tree().current_scene.get_node_or_null("HUD")
					if hud_node and hud_node.has_method("show_message"):
						hud_node.show_message("Vào đường hầm: Tự động chuyển về góc nhìn Cabin")
					break
	
	_animate_doors(delta)

func _animate_doors(delta):
	# Fallback: resolve nearest station if current_station is null
	if current_station == null:
		var nearest = get_nearest_station()
		if nearest:
			current_station = nearest

	# Determine which side to open based on global X axis
	var open_minus_x = false
	var open_plus_x = false
	if doors_open:
		if current_station:
			var side = current_station.platform_side
			if side == -1: open_minus_x = true # -1 means Left (-X)
			elif side == 1: open_plus_x = true # 1 means Right (+X)
			else: 
				open_minus_x = true
				open_plus_x = true
		else:
			# If no station, doors won't open (but just in case)
			pass
	
	var target_minus_x = 1.0 if open_minus_x else 0.0
	var target_plus_x = 1.0 if open_plus_x else 0.0
	
	global_door_progress_left = move_toward(global_door_progress_left, target_minus_x, delta * 1.5)
	global_door_progress_right = move_toward(global_door_progress_right, target_plus_x, delta * 1.5)
	
	for j in range(cars.size()):
		var car = cars[j]
		var is_last = (j == cars.size() - 1)
		var car_rotated = (is_last and direction_forward) or (not is_last and not direction_forward)
		
		var body = car.get_node_or_null("Body")
		if body is CSGShape3D:
			if car_rotated:
				# Rotated: local +Z is -X, local -Z is +X
				body.set_instance_shader_parameter("door_progress_right", global_door_progress_left) # right(+Z) -> minus_x
				body.set_instance_shader_parameter("door_progress_left", global_door_progress_right) # left(-Z) -> plus_x
			else:
				# Unrotated: local +Z is +X, local -Z is -X
				body.set_instance_shader_parameter("door_progress_right", global_door_progress_right) # right(+Z) -> plus_x
				body.set_instance_shader_parameter("door_progress_left", global_door_progress_left) # left(-Z) -> minus_x


	
func _handle_input(delta):
	if doors_open:
		current_throttle = move_toward(current_throttle, 0.0, delta * 2.0)
		return
		
	if not is_player_controlled:
		current_throttle = move_toward(current_throttle, 1.0, delta * 0.5)
		return
		
	# Keyboard input modifies the persistent throttle
	var input_dir = Input.get_axis("throttle_down", "throttle_up")
	if input_dir != 0:
		current_throttle += input_dir * 1.5 * delta
		
	current_throttle = clamp(current_throttle, 0.0, 1.0)

func _update_physics(delta):
	var speed_before = current_speed
	var is_auto_parking = false
	# Auto-parking logic
	if auto_stop_enabled and current_station and not current_station.stop_completed:
		var station_local = path_node.to_local(current_station.global_transform.origin)
		var station_offset = path_node.curve.get_closest_offset(station_local)
		
		# Dừng ngay sát mép nhà ga phía hướng đi tới. Platform kéo dài từ -50 đến +50.
		# Đầu tàu (car1 ở train_progress) sẽ dừng tại +45 để nằm trọn trong ga.
		var target_offset = station_offset + 45.0 if direction_forward else station_offset - 45.0
		var remaining_dist = target_offset - train_progress if direction_forward else train_progress - target_offset
		
		if remaining_dist > 0 and remaining_dist < 130.0:
			is_auto_parking = true
			current_throttle = 0.0
			# Giảm tốc từ từ: Tốc độ giảm tuyến tính theo khoảng cách còn lại
			var ideal_speed = max_speed * (remaining_dist / 130.0)
			ideal_speed = max(ideal_speed, 2.0) if remaining_dist > 2.0 else ideal_speed
			
			if current_speed > ideal_speed:
				current_speed = move_toward(current_speed, ideal_speed, braking_force * delta)
			
			if remaining_dist < 0.2:
				current_speed = 0.0
				
			if current_speed <= 10.0 and current_speed > 1.0 and not has_played_approach_sound:
				has_played_approach_sound = true
				if approach_audio and approach_audio.stream: approach_audio.play()

	if current_throttle > 0.0 and abs(current_speed) < 2.0 and current_station != null and doors_open == false:
		if not is_block_clear():
			if is_player_controlled:
				var hud = get_node_or_null("/root/Main/HUD")
				if hud and hud.has_method("trigger_game_over"):
					hud.trigger_game_over("Vượt đèn đỏ! Tàu phía trước chưa rời ga kế tiếp.")
			current_throttle = 0.0

	if current_throttle > 0:
		var target_speed = max_speed * current_throttle
		if current_speed < target_speed:
			current_speed = move_toward(current_speed, target_speed, acceleration * delta)
		else:
			current_speed = move_toward(current_speed, target_speed, friction * delta)
	elif not is_auto_parking:
		# Throttle is 0, apply braking to stop
		current_speed = move_toward(current_speed, 0.0, braking_force * delta)
		
	current_speed = clamp(current_speed, 0.0, max_speed)
	
	if path_node and not follows.is_empty():
		var speed_ms = current_speed * 0.277778
		if direction_forward:
			train_progress += speed_ms * delta
		else:
			train_progress -= speed_ms * delta
		
		var total_length = path_node.curve.get_baked_length()
		if total_length > 0:
			for j in range(cars.size()):
				var progress_offset = -j * 21.0 if direction_forward else j * 21.0
				follows[j].progress = train_progress + progress_offset
				
				var is_last = (j == cars.size() - 1)
				var rot_y = 0.0
				if direction_forward:
					rot_y = PI if is_last else 0.0
				else:
					rot_y = 0.0 if is_last else PI
				var basis = Basis().rotated(Vector3.UP, rot_y)
				if j < cars.size() and j < follows.size():
					cars[j].global_transform = follows[j].global_transform * Transform3D(basis, Vector3(0, 0.5, 0))

	# Play stopping sound when slowing down inside the station
	var is_braking_near_station = false
	if current_station != null:
		var station_local = path_node.to_local(current_station.global_transform.origin)
		var station_offset = path_node.curve.get_closest_offset(station_local)
		var target_offset = station_offset + 45.0 if direction_forward else station_offset - 45.0
		var remaining_dist = target_offset - train_progress if direction_forward else train_progress - target_offset
		if remaining_dist > 0 and remaining_dist < 140.0:
			is_braking_near_station = true
			
	if is_braking_near_station and speed_before > current_speed and current_speed > 0.5:
		if not has_played_stop_sound:
			has_played_stop_sound = true
			if stopping_audio and stopping_audio.stream:
				stopping_audio.play()
				print("[Train] Slowing down in station, playing stopping sound. Speed: ", current_speed)
			has_played_approach_sound = false
			has_played_depart_sound = false

	# Check for complete stop (fallback)
	if speed_before > 0.01 and current_speed <= 0.01:
		if not has_played_stop_sound:
			has_played_stop_sound = true
			if stopping_audio and stopping_audio.stream:
				stopping_audio.play()
				print("[Train] Complete stop fallback, playing stopping sound.")
			has_played_approach_sound = false
			has_played_depart_sound = false
	elif current_speed > 5.0:
		has_played_stop_sound = false

	if current_throttle > 0.0 and current_speed < 5.0 and not has_played_depart_sound:
		has_played_depart_sound = true
		if depart_audio and depart_audio.stream: depart_audio.play()

	if bridge_sound_cooldown > 0:
		bridge_sound_cooldown -= delta
	else:
		if current_speed > 5.0:
			var current_y = car1.global_transform.origin.y
			var current_yaw = car1.global_transform.basis.get_euler().y
			var velocity_y = abs(current_y - prev_y) / delta
			var angular_vel = abs(angle_difference(current_yaw, prev_yaw)) / delta
			
			if velocity_y > 0.5 or angular_vel > 0.05:
				if bridge_audio and bridge_audio.stream and not bridge_audio.playing:
					bridge_audio.play()
					bridge_sound_cooldown = 15.0 # Cooldown 15s
			
			prev_y = current_y
			prev_yaw = current_yaw


func get_camera_muffle() -> float:
	if cameras.is_empty() or current_camera_index >= cameras.size():
		return 0.0
	var cam_name = cameras[current_camera_index].name
	if cam_name in ["Cam_Cabin", "Cam_Car_1", "Cam_Car_2", "Cam_Car_3"]:
		return -15.0 if not doors_open else -2.0
	elif cam_name == "Cam_Side":
		return -8.0 # Giảm nhẹ tiếng ồn khi ở Cam_Side
	elif cam_name == "Cam_Front":
		return 0.0 # To nhất khi nhìn thẳng từ đầu tàu
	elif cam_name in ["Cam_ThirdPerson", "Cam_Isometric"]:
		return -18.0 # Giảm rất nhiều khi nhìn từ Flycam/Top view
	return 0.0

func _update_audio(_delta):
	var muffle_db = get_camera_muffle()
		
	# Update running audio
	if running_audio and running_audio.stream:
		var speed_ratio = current_speed / max_speed
		if speed_ratio > 0.01:
			running_audio.pitch_scale = 0.5 + speed_ratio * 0.5
			running_audio.volume_db = lerp(-20.0, 0.0, speed_ratio) + muffle_db
			if not running_audio.playing:
				running_audio.play()
		else:
			running_audio.volume_db = -80.0

	# Apply muffle to other external sounds
	for audio in [approach_audio, depart_audio, bridge_audio, stopping_audio, horn_audio]:
		if audio and audio.stream:
			audio.volume_db = 0.0 + muffle_db


func is_camera_inside() -> bool:
	if cameras.is_empty() or current_camera_index >= cameras.size():
		return false
	var cam_name = cameras[current_camera_index].name
	return cam_name in ["Cam_Cabin", "Cam_Car_1", "Cam_Car_2", "Cam_Car_3"]


func toggle_doors():
	if not doors_open:
		return open_doors()
	else:
		return close_doors()

func open_doors() -> bool:
	if abs(current_speed) < 0.01: # Only allow opening when completely stopped (0km/h)
		if is_player_controlled and current_station == null:
			var hud = get_node_or_null("/root/Main/HUD")
			if hud and hud.has_method("trigger_game_over"):
				hud.trigger_game_over("Mở cửa khi không đỗ tại nhà ga!")
			return false
			
		doors_open = true
		if doors_audio and doors_audio.stream: doors_audio.play()
		print("Doors opened")
		doors_opened.emit()
		return true
	return false

func close_doors() -> bool:
	if abs(current_speed) < 2.0:
		doors_open = false
		if doors_audio and doors_audio.stream: doors_audio.play()
		print("Doors closed")
		doors_closed.emit()
		return true
	return false

func get_speed() -> float:
	return current_speed

func get_throttle() -> float:
	return current_throttle

func get_distance_to_next_station() -> float:
	var stations = _get_stations()
	if stations.is_empty():
		return INF
	var min_dist = INF
	for station in stations:
		# Use car1 position (actual train front) instead of root node
		var dist = (car1.global_transform.origin - station.global_transform.origin).length()
		if dist < min_dist:
			min_dist = dist
	return min_dist / 1000.0 # return km






func is_block_clear() -> bool:
	var trains = _get_trains()
	var my_path = get_parent()
	var next_station_offset = -1
	if current_station:
		var station_local = path_node.to_local(current_station.global_transform.origin)
		var station_offset = path_node.curve.get_closest_offset(station_local)
		if direction_forward:
			next_station_offset = station_offset + 1500.0
		else:
			next_station_offset = station_offset - 1500.0
	else:
		return true
		
	for t in trains:
		if t == self: continue
		if t.get_parent() != my_path: continue
		if "direction_forward" in t and t.direction_forward != direction_forward: continue
		
		var t_prog = t.train_progress
		if direction_forward:
			if t_prog > train_progress and t_prog < next_station_offset + 300.0:
				return false
		else:
			if t_prog < train_progress and t_prog > next_station_offset - 300.0:
				return false
				
	return true


func reverse_direction():
	# Bù trừ chiều dài tàu để giữ nguyên vị trí vật lý của đoàn tàu
	var spacing = 21.0 * (cars.size() - 1)
	if direction_forward:
		train_progress -= spacing
	else:
		train_progress += spacing
		
	direction_forward = not direction_forward
	doors_open = false
	current_speed = 0.0
	current_throttle = 0.0
	
	var hud = get_node_or_null("/root/Main/HUD")
	if hud and hud.has_method("update_door_status"):
		hud.update_door_status(false)

func get_open_door_global_positions() -> Array:
	var list = []
	if not doors_open or not current_station:
		return list
		
	var is_shinkansen = "shinkansen" in str(name).to_lower() or "shinkansen" in scene_file_path.to_lower()
	var is_cat_linh = "catlinh" in str(name).to_lower() or "catlinh" in scene_file_path.to_lower()
	
	var side = current_station.platform_side # -1: Left (-X), 1: Right (+X), 0: Both
	var open_left = (side == -1 or side == 0)
	var open_right = (side == 1 or side == 0)
	
	for j in range(cars.size()):
		var car = cars[j]
		if is_shinkansen and (j != 0 and j != cars.size() - 1):
			continue
			
		var local_xs = []
		if is_shinkansen:
			local_xs = [3.75]
		elif is_cat_linh:
			local_xs = [3.5, 7.8, 12.2, 16.5]
		else:
			local_xs = [3.75, 10.25, 16.75]
			
		var is_last = (j == cars.size() - 1)
		var car_rotated = (is_last and direction_forward) or (not is_last and not direction_forward)
		
		for lx in local_xs:
			# In unrotated car: local Z = -1.5 is left (-X in world), local Z = 1.5 is right (+X in world)
			# In rotated car: local Z = -1.5 is right (+X in world), local Z = 1.5 is left (-X in world)
			if open_left:
				var local_z = -1.5 if car_rotated else 1.5
				list.append({
					"position": car.global_transform * Vector3(lx, 0.0, local_z),
					"car": car
				})
			if open_right:
				var local_z = 1.5 if car_rotated else -1.5
				list.append({
					"position": car.global_transform * Vector3(lx, 0.0, local_z),
					"car": car
				})
				
	return list
