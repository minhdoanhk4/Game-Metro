extends Area3D

@export var station_name: String = "Central Station"
@export_enum("Left:-1", "Both:0", "Right:1") var platform_side: int = 1

var train_in_station: Node = null

# Per-lap stop tracking
var stop_completed: bool = false     # true after full stop done this lap
var doors_opened_here: bool = false  # doors were opened while stopped at this station
var auto_open_timer: float = 0.0    # delay before auto-opening doors

var safe_zone_mesh: CSGBox3D = null
var train_was_moving: bool = false
var has_checked_parking: bool = false
var welcome_played_this_stop: bool = false
var time_at_station_without_opening: float = 0.0
var penalty_applied: bool = false

var welcome_audio: AudioStreamPlayer3D
var bg_audio: AudioStreamPlayer3D

@onready var main_scene = get_tree().current_scene

func _ready():
	add_to_group("stations")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	call_deferred("_setup_safe_zone")
	_setup_audio()
	call_deferred("_setup_visuals")



func _setup_audio():
	bg_audio = AudioStreamPlayer3D.new()
	bg_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	bg_audio.max_distance = 400.0
	bg_audio.unit_size = 25.0
	add_child(bg_audio)
	
	var bg_stream = null
	if ResourceLoader.exists("res://Assets/sound-of-tieng-nha-ga-ben-ngoai-tau.mp3"):
		bg_stream = load("res://Assets/sound-of-tieng-nha-ga-ben-ngoai-tau.mp3")
	elif ResourceLoader.exists("res://Assets/bg_sound.wav"):
		bg_stream = load("res://Assets/bg_sound.wav")
		
	if bg_stream:
		if bg_stream is AudioStreamWAV:
			bg_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			bg_stream.loop_begin = 0
			bg_stream.loop_end = 0
		elif "loop" in bg_stream:
			bg_stream.loop = true
		bg_audio.stream = bg_stream
		bg_audio.play()
		bg_audio.volume_db = -80.0

	# Welcome Audio (voice announcement)
	welcome_audio = AudioStreamPlayer3D.new()
	welcome_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	welcome_audio.max_distance = 200.0
	welcome_audio.unit_size = 15.0
	add_child(welcome_audio)
	if ResourceLoader.exists("res://Assets/station_welcome.wav"):
		welcome_audio.stream = load("res://Assets/station_welcome.wav")

func _setup_safe_zone():
	var path_node = main_scene.get_node_or_null("Path3D")
	if not path_node: return
	
	var station_local = path_node.to_local(global_transform.origin)
	var station_offset = path_node.curve.get_closest_offset(station_local)
	var target_offset = station_offset + 45.0
	
	var t_local = path_node.curve.sample_baked_with_rotation(target_offset)
	var t_global = path_node.global_transform * t_local
	
	safe_zone_mesh = CSGBox3D.new()
	safe_zone_mesh.size = Vector3(6.0, 0.2, 6.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.2, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	safe_zone_mesh.material = mat
	
	main_scene.add_child(safe_zone_mesh)
	safe_zone_mesh.global_transform = t_global
	safe_zone_mesh.global_transform.origin += Vector3(0, 0.3, 0)
	safe_zone_mesh.visible = false

func _on_area_entered(area):
	var train = null
	if area.get_parent() is Train:
		train = area.get_parent()
	elif area.get_parent() and area.get_parent().get_parent() is Train:
		train = area.get_parent().get_parent()
		
	print("[Station ", station_name, "] _on_area_entered: area=", area.name, " train=", train, " train_in_station=", train_in_station)
	if train:
		if train == train_in_station:
			print("[Station ", station_name, "] Already tracking this train, ignoring re-entry.")
			return  # Already tracking this train, prevent reset by multiple cars
		if stop_completed:
			print("[Station ", station_name, "] Stop already completed this lap, ignoring.")
			return  # stop already done this lap, ignore re-entry
		train_in_station = train
		train_in_station.current_station = self
		# Sync door state immediately on entry (handles spawn-at-station with open doors)
		doors_opened_here = train.doors_open
		stop_completed = false
		auto_open_timer = 0.0
		has_checked_parking = false
		welcome_played_this_stop = false
		time_at_station_without_opening = 0.0
		penalty_applied = false
		print("[Station ", station_name, "] Started tracking new train. doors_opened_here=", doors_opened_here, ", stop_completed=false")
		train_was_moving = true
		if train.is_player_controlled and safe_zone_mesh:
			safe_zone_mesh.visible = true

func _on_area_exited(area):
	var train = null
	if area.get_parent() is Train:
		train = area.get_parent()
	elif area.get_parent() and area.get_parent().get_parent() is Train:
		train = area.get_parent().get_parent()
		
	print("[Station ", station_name, "] _on_area_exited: area=", area.name, " train=", train, " train_in_station=", train_in_station)
	
	if train and train == train_in_station:
		# If the train is still stopped (speed < 2.0), ignore the exit signal (probably physics jitter)
		if abs(train.get_speed()) < 2.0:
			print("[Station ", station_name, "] Train exited but speed is < 2.0. Ignoring exit.")
			return
			
		if train.current_station == self:
			train.current_station = null
			
		if train.is_player_controlled and not stop_completed:
			var hud = get_node_or_null("/root/Main/HUD")
			if hud and hud.has_method("trigger_game_over"):
				hud.trigger_game_over("Bỏ trạm hoặc vượt quá điểm dừng tại ga " + station_name + "!")
				
		train_in_station = null
		auto_open_timer = 0.0
		print("[Station ", station_name, "] Cleared train_in_station on exit.")

# Called by HUD after train moves away (> 2 km) following a completed stop
func reset_for_next_lap():
	stop_completed = false
	doors_opened_here = false
	auto_open_timer = 0.0
	time_at_station_without_opening = 0.0
	penalty_applied = false

func _process(delta):
	_update_station_audio(delta)
	
	if not train_in_station:
		return

	var speed = abs(train_in_station.get_speed())

	if speed >= 2.0:
		train_was_moving = true
		has_checked_parking = false
	elif speed < 2.0 and train_was_moving and not has_checked_parking:
		has_checked_parking = true
		train_was_moving = false
		if safe_zone_mesh:
			safe_zone_mesh.visible = false

	# Instead of checking violation the moment train stops, check it when doors open
	var check_violation_func = func():
		if not train_in_station.is_player_controlled: return false
		
		var platform_length = 160.0
		var yline = get_node_or_null("YellowLine")
		if yline and yline is CSGBox3D:
			platform_length = yline.size.z
			
		var station_z = global_transform.origin.z
		var tolerance = 1.0 # 1.0 meter safety margin for sliding/floating point precision
		var min_z = station_z - (platform_length / 2.0) - tolerance
		var max_z = station_z + (platform_length / 2.0) + tolerance
		var is_violation = false
		var max_door_dist = 0.0
		
		var car1_z = train_in_station.car1.global_transform.origin.z
		var car3_z = train_in_station.car3.global_transform.origin.z
		var min_train_z = min(car1_z, car3_z) - 5.0  # Nose/rear buffer
		var max_train_z = max(car1_z, car3_z) + 5.0
		
		if min_train_z < min_z or max_train_z > max_z:
			is_violation = true
			if min_train_z < min_z:
				max_door_dist = min_z - min_train_z
			else:
				max_door_dist = max_train_z - max_z
				
		if is_violation:
			var hud = get_node_or_null("/root/Main/HUD")
			if hud and hud.has_method("trigger_game_over"):
				hud.trigger_game_over("Tàu đỗ sai vị trí! Có cửa nằm ngoài sân đỗ (Lệch " + str(snapped(max_door_dist, 0.1)) + "m)")
			return true
		return false

	# Auto-open doors is disabled per user request (manual only)
	# Play welcome audio 1 second after stopping
	if speed < 0.01 and not doors_opened_here and not stop_completed:
		auto_open_timer += delta
		if auto_open_timer >= 1.0 and not welcome_played_this_stop:
			welcome_played_this_stop = true
			if welcome_audio and welcome_audio.stream: welcome_audio.play()
			
	if speed < 2.0 and not doors_opened_here and not stop_completed:
		if train_in_station.is_player_controlled and not penalty_applied:
			time_at_station_without_opening += delta
			var limit = 10.0
			if GameManager and "time_scale" in GameManager:
				limit = 120.0 / GameManager.time_scale
				
			if time_at_station_without_opening >= limit:
				penalty_applied = true
				if GameManager:
					GameManager.add_money(-50)
				var hud = get_node_or_null("/root/Main/HUD")
				if hud and hud.has_method("show_message"):
					hud.show_message("Bị phạt 50$ vì đỗ lố 2 phút không mở cửa!")
	else:
		if speed >= 2.0:
			auto_open_timer = 0.0  # reset if train moves again
			time_at_station_without_opening = 0.0



	# Track that doors were opened while stopped here
	if train_in_station.doors_open and speed < 2.0 and not doors_opened_here:
		print("[Station ", station_name, "] Doors are open and speed < 2.0. Checking violation for doors_opened_here...")
		if check_violation_func.call(): 
			print("[Station ", station_name, "] Violation detected, aborting doors_opened_here setting.")
			return
		doors_opened_here = true
		print("[Station ", station_name, "] Set doors_opened_here = true")
		if train_in_station.is_player_controlled:
			var is_final = false
			if train_in_station.direction_forward and station_name.to_upper() == "THU DUC":
				is_final = true
			elif not train_in_station.direction_forward and station_name.to_upper() == "BEN THANH":
				is_final = true
				
			if is_final:
				var hud = get_node_or_null("/root/Main/HUD")
				if hud and hud.has_method("trigger_victory"):
					hud.trigger_victory()

	# Detect: doors closed after being opened → stop cycle complete
	if doors_opened_here and not train_in_station.doors_open and not stop_completed:
		print("[Station ", station_name, "] Detect doors closed. doors_opened_here=true, stop_completed=false. Completing stop cycle.")
		stop_completed = true
		if train_in_station.is_player_controlled:
			# Money is now handled dynamically per passenger boarding/alighting in PassengerManager
			if main_scene.has_method("process_station_stop"):
				main_scene.process_station_stop(station_name)
		# Release the train reference so we don't keep processing
		train_in_station = null
		print("[Station ", station_name, "] Stop cycle completed. train_in_station set to null.")

func get_door_open_time() -> float:
	if train_in_station and train_in_station.doors_open:
		return auto_open_timer
	return 0.0


var cached_player_train: Node = null

func _update_station_audio(_delta):
	# Find the player train dynamically (cached to prevent lag)
	if not is_instance_valid(cached_player_train):
		var trains = get_tree().get_nodes_in_group("train")
		for t in trains:
			if t.get("is_player_controlled"):
				cached_player_train = t
				break
			
	var player_train = cached_player_train
			
	if not player_train or not player_train.get("car1") or not is_instance_valid(player_train.car1):
		if bg_audio and bg_audio.playing:
			bg_audio.stop()
		return

	# Calculate distance between train front (car1) and this station
	var train_pos = player_train.car1.global_transform.origin
	var dist = (train_pos - global_transform.origin).length()
	
	# Fade logic:
	# Full volume (1.0) when dist <= 50.0m
	# Linearly fade out to silence (0.0) from 50.0m to 250.0m
	# Silence (0.0) when dist >= 250.0m
	var volume_factor = 1.0
	if dist > 250.0:
		volume_factor = 0.0
	elif dist > 50.0:
		volume_factor = 1.0 - ((dist - 50.0) / 200.0)
		
	# Muffle logic if player camera is inside closed train or using a muffled camera
	var muffle_db = 0.0
	if player_train.has_method("get_camera_muffle"):
		muffle_db = player_train.get_camera_muffle()
		
	if bg_audio:
		if volume_factor > 0.001:
			var max_bg_vol = -5.0 # Base max volume for the station ambient sound
			var target_vol = max_bg_vol + linear_to_db(volume_factor) + muffle_db
			bg_audio.volume_db = clamp(target_vol, -80.0, 10.0)
			if not bg_audio.playing:
				bg_audio.play()
		else:
			if bg_audio.playing:
				bg_audio.stop()
				
	# Also apply muffle to welcome announcement if it plays
	if welcome_audio and welcome_audio.playing:
		welcome_audio.volume_db = 0.0 + muffle_db

func _setup_visuals():
	var is_underground = global_transform.origin.y < -5.0
	
	if is_underground:
		# 1. Spawn bright lights
		for z_offset in range(-70, 71, 20):
			var light = OmniLight3D.new()
			light.position = Vector3(0.0, 4.0, z_offset)
			light.omni_range = 35.0
			light.light_color = Color(1.0, 0.95, 0.8)
			light.light_energy = 5.0
			light.shadow_enabled = true
			add_child(light)
			
		# 2. Big signs on the walls
		for z_offset in [-60, -20, 20, 60]:
			var wall_sign = CSGBox3D.new()
			wall_sign.size = Vector3(0.2, 1.5, 8.0)
			
			var plat_x = 0.0
			var plat_node = get_node_or_null("Platform")
			if plat_node: plat_x = plat_node.position.x
			else: plat_x = 3.5 if platform_side == 1 else -3.5
			
			# Put sign on the wall behind the platform
			var wall_x = plat_x + sign(plat_x) * 1.5
			if plat_x == 0: wall_x = 5.0
			
			wall_sign.position = Vector3(wall_x, 2.5, z_offset)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.1, 0.3, 0.8)
			wall_sign.material = mat
			add_child(wall_sign)
			
			var lbl = Label3D.new()
			lbl.text = station_name
			lbl.font_size = 180
			lbl.position = Vector3(sign(wall_x) * -0.11, 0, 0)
			if sign(wall_x) < 0: lbl.rotation_degrees.y = 90
			else: lbl.rotation_degrees.y = -90
			wall_sign.add_child(lbl)
			
		# 3. Platform Screen Doors (PSD)
		var yline = get_node_or_null("YellowLine")
		if yline:
			var psd_x = yline.position.x
			var y_base = yline.position.y - 0.01
			
			var psd_wall = CSGBox3D.new()
			psd_wall.size = Vector3(0.1, 3.5, 160.0)
			psd_wall.position = Vector3(psd_x, y_base + 1.75, 0)
			var glass_mat = StandardMaterial3D.new()
			glass_mat.albedo_color = Color(0.4, 0.7, 0.9, 0.4)
			glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			psd_wall.material = glass_mat
			add_child(psd_wall)
			
			for z_offset in range(-80, 81, 5):
				var post = CSGBox3D.new()
				post.size = Vector3(0.15, 3.5, 0.15)
				post.position = Vector3(psd_x, y_base + 1.75, z_offset)
				var post_mat = StandardMaterial3D.new()
				post_mat.albedo_color = Color(0.2, 0.2, 0.2)
				post_mat.metallic = 0.8
				post_mat.roughness = 0.2
				post.material = post_mat
				add_child(post)
			
			var header = CSGBox3D.new()
			header.size = Vector3(0.2, 0.3, 160.0)
			header.position = Vector3(psd_x, y_base + 3.35, 0)
			var h_mat = StandardMaterial3D.new()
			h_mat.albedo_color = Color(0.2, 0.2, 0.2)
			header.material = h_mat
			add_child(header)
	else:
		# Elevated station signs - Overhead hanging sign to avoid track collision
		var overhead_beam = CSGBox3D.new()
		# Extended size from 12.0 to 14.0 to reach the side walls
		overhead_beam.size = Vector3(14.0, 0.4, 0.4)
		overhead_beam.position = Vector3(0.0, 7.5, 0.0)
		var beam_mat = StandardMaterial3D.new()
		beam_mat.albedo_color = Color(0.2, 0.2, 0.2)
		overhead_beam.material = beam_mat
		add_child(overhead_beam)
		
		# Hanging Sign Board
		var hanging_sign = CSGBox3D.new()
		hanging_sign.size = Vector3(8.0, 1.5, 0.2)
		hanging_sign.position = Vector3(0.0, 6.5, 0.0)
		var bg_mat = StandardMaterial3D.new()
		bg_mat.albedo_color = Color(0.1, 0.4, 0.8)
		hanging_sign.material = bg_mat
		add_child(hanging_sign)
		
		# Text on hanging sign (both sides)
		for rot in [0, 180]:
			var lbl = Label3D.new()
			lbl.text = station_name
			lbl.font_size = 180
			lbl.position = Vector3(0, 0, 0.11 if rot == 0 else -0.11)
			lbl.rotation_degrees.y = rot
			hanging_sign.add_child(lbl)
		


	# Add legs to the existing StationSign so it's placed on the platform floor
	var existing_sign = get_node_or_null("StationSign")
	if existing_sign:
		# existing sign is usually at y=2.5, platform surface is y=1.0
		# We need 2 legs (left and right)
		for x_offset in [-0.8, 0.8]:
			var leg = CSGBox3D.new()
			leg.size = Vector3(0.1, 1.5, 0.1)
			leg.position = Vector3(x_offset, -0.75, 0.0) # Local to sign
			var leg_mat = StandardMaterial3D.new()
			leg_mat.albedo_color = Color(0.3, 0.3, 0.3)
			leg_mat.metallic = 0.8
			leg.material = leg_mat
			existing_sign.add_child(leg)
