extends Node

var passenger_scene = preload("res://Scripts/Passenger.gd")

var platform_passengers: Array = []
var train_passengers: Array = []

var connected_train: Train = null
var last_station: Node = null

# Stop-specific tracking
var stop_time_minutes: float = 0.0
var doors_opened_this_stop: bool = false
var horn_blown_before_open: bool = false
var horn_blown_before_close: bool = false
var has_penalized_no_open: bool = false
var has_penalized_timeout: bool = false
var passengers_spawned: bool = false

var boarded_count: int = 0
var alighted_count: int = 0
var door_queues: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_spawn_initial_passengers")

func _process(delta):
	# Don't process logic if the game is paused
	if get_tree().paused:
		return
		
	# Find player train dynamically
	var trains = get_tree().get_nodes_in_group("train")
	var player_train: Train = null
	for t in trains:
		if t.is_player_controlled:
			player_train = t
			break
			
	# Update signal connections
	if player_train != connected_train:
		if is_instance_valid(connected_train):
			if connected_train.horn_blown.is_connected(_on_train_horn_blown):
				connected_train.horn_blown.disconnect(_on_train_horn_blown)
			if connected_train.doors_opened.is_connected(_on_train_doors_opened):
				connected_train.doors_opened.disconnect(_on_train_doors_opened)
			if connected_train.doors_closed.is_connected(_on_train_doors_closed):
				connected_train.doors_closed.disconnect(_on_train_doors_closed)
				
		connected_train = player_train
		if is_instance_valid(connected_train):
			connected_train.horn_blown.connect(_on_train_horn_blown)
			connected_train.doors_opened.connect(_on_train_doors_opened)
			connected_train.doors_closed.connect(_on_train_doors_closed)
			
	if not is_instance_valid(connected_train):
		return
		
	# Track station stop timers
	var station = connected_train.current_station
	if station:
		if station != last_station:
			# New station stop initiated
			last_station = station
			stop_time_minutes = 0.0
			doors_opened_this_stop = false
			horn_blown_before_open = false
			horn_blown_before_close = false
			has_penalized_no_open = false
			has_penalized_timeout = false
			passengers_spawned = false
			boarded_count = 0
			alighted_count = 0
			
		var speed = abs(connected_train.get_speed())
		if speed < 0.01:
			# Train is stopped at the station
			# Convert real delta to game minutes (12x time scale)
			var game_delta_minutes = (delta / 60.0) * GameManager.time_scale
			stop_time_minutes += game_delta_minutes
			
			# Refill platform passengers if they are low
			if not passengers_spawned:
				passengers_spawned = true
				var local_count = 0
				for p in platform_passengers:
					if is_instance_valid(p) and p.global_position.distance_to(station.global_position) < 80.0:
						local_count += 1
				if local_count < 40:
					var refill_needed = randi_range(50, 80) - local_count
					if refill_needed > 0:
						_spawn_platform_passengers_count(station, refill_needed)
				
			# Check Timeout 1: 2 game minutes without opening doors
			if not doors_opened_this_stop and stop_time_minutes > 2.0 and not has_penalized_no_open:
				has_penalized_no_open = true
				GameManager.add_money(-50)
				_show_hud_warning("VI PHẠM:\nQUÁ 2 PHÚT CHƯA MỞ CỬA TÀU!\n-50$")
				
			# Check Timeout 2: 8 game minutes total station stop time
			if stop_time_minutes > 8.0 and not has_penalized_timeout:
				has_penalized_timeout = true
				GameManager.add_money(-50)
				_show_hud_warning("VI PHẠM:\nQUÁ GIỜ GIÃN CÁCH ĐÓN TRẢ KHÁCH\n(8 PHÚT)! -50$")
	else:
		if last_station != null:
			# Train left the station (cleanup is skipped in persistent passenger mode)
			last_station = null

	# Update door queues for boarding passengers
	if not door_queues.is_empty():
		for q_key in door_queues.keys():
			var q = door_queues[q_key]
			if not q.alight_finished:
				q.alight_timer -= delta
				if q.alight_timer <= 0.0:
					q.alight_finished = true
			else:
				q.board_timer -= delta
				if q.board_timer <= 0.0:
					q.board_timer = 0.4 # release next passenger every 0.4 seconds
					if not q.passengers.is_empty():
						var p = q.passengers.pop_front()
						if is_instance_valid(p):
							p.start_boarding()
						# Update remaining queue indices so passengers move forward
						for idx in range(q.passengers.size()):
							var next_p = q.passengers[idx]
							if is_instance_valid(next_p):
								next_p.update_queue_index(q.queue_dir, idx)

func _spawn_initial_passengers():
	var stations = _get_stations()
	print("[PassengerManager] Spawning persistent Minecraft passengers (50-80 per station). Total stations: ", stations.size())
	for station in stations:
		var count = randi_range(50, 80)
		_spawn_platform_passengers_count(station, count)

func _spawn_platform_passengers(station: Node):
	var count = randi_range(50, 80)
	_spawn_platform_passengers_count(station, count)

func _spawn_platform_passengers_count(station: Node, count: int):
	var plat_node = station.get_node_or_null("Platform")
	var plat_pos = station.global_position
	if plat_node:
		plat_pos = plat_node.global_position
		
	var main_scene = get_tree().current_scene
	for i in range(count):
		var p = Node3D.new()
		p.set_script(passenger_scene)
		main_scene.add_child(p)
		
		# Position randomly on the platform surface
		var spawn_x = plat_pos.x + randf_range(-1.0, 1.0)
		var spawn_z = plat_pos.z + randf_range(-55.0, 55.0)
		var spawn_y = plat_pos.y + 0.5
		
		p.global_position = Vector3(spawn_x, spawn_y, spawn_z)
		p.original_waiting_pos = p.global_position
		p.state = passenger_scene.State.WAITING
		platform_passengers.append(p)

func _cleanup_platform_passengers():
	# Skip clearing to maintain persistent crowd simulation
	pass

func _get_stations() -> Array:
	var stations = get_tree().get_nodes_in_group("stations")
	return stations

func _on_train_horn_blown():
	if last_station:
		var speed = abs(connected_train.get_speed())
		if speed < 0.05:
			if not doors_opened_this_stop:
				horn_blown_before_open = true
				print("[PassengerManager] Horn blown before door open")
			else:
				horn_blown_before_close = true
				print("[PassengerManager] Horn blown before door close")

func _on_train_doors_opened():
	if not last_station:
		return
		
	doors_opened_this_stop = true
	
	# Verify horn rule before open
	if not horn_blown_before_open:
		GameManager.add_money(-20)
		_show_hud_warning("VI PHẠM:\nKHÔNG BẤM CÒI CẢNH BÁO\nTRƯỚC KHI MỞ CỬA! -20$")
	
	var doors = connected_train.get_open_door_global_positions()
	if doors.is_empty():
		return
		
	# Initialize door queues
	door_queues.clear()
	for door in doors:
		var q_key = door.position
		var queue_dir = Vector3(1, 0, 0)
		if door.position.x > last_station.global_position.x:
			queue_dir = Vector3(1, 0, 0)
		else:
			queue_dir = Vector3(-1, 0, 0)
			
		door_queues[q_key] = {
			"door_pos": door.position,
			"queue_dir": queue_dir,
			"car": door.car,
			"passengers": [],
			"board_timer": randf_range(0.4, 0.8),
			"alight_timer": 1.5,
			"alight_finished": false
		}
	
	# 1. Trigger platform passengers to board (Only a randomized subset close to the train will board)
	var main_scene = get_tree().current_scene
	var station_passengers = []
	for p in platform_passengers:
		if is_instance_valid(p) and (p.state == passenger_scene.State.WAITING or p.is_wandering):
			# Filter to only check passengers at the current station platform (within 80m of train front)
			var dist = p.global_position.distance_to(connected_train.car1.global_position)
			if dist < 80.0:
				station_passengers.append(p)
				
	# Randomize boarding choice: 20% to 40% of waiting passengers board the train
	if not station_passengers.is_empty():
		station_passengers.shuffle()
		var board_ratio = randf_range(0.20, 0.40)
		var board_limit = clamp(int(station_passengers.size() * board_ratio), 1, station_passengers.size())
		
		for k in range(board_limit):
			var p = station_passengers[k]
			# Find nearest door queue
			var nearest_q = null
			var min_dist = INF
			for q_key in door_queues:
				var q = door_queues[q_key]
				var d_dist = p.global_position.distance_to(q.door_pos)
				if d_dist < min_dist:
					min_dist = d_dist
					nearest_q = q
			if nearest_q and min_dist < 40.0:
				var q_index = nearest_q.passengers.size()
				nearest_q.passengers.append(p)
				p.go_to_queue(nearest_q.door_pos, nearest_q.queue_dir, q_index, connected_train, nearest_q.car)
				
	# 2. Trigger alighting for passengers inside the train (tracked in train_passengers and invisible)
	# Count INSIDE_TRAIN passengers that belong to this train
	var alighting_candidates = []
	for p in train_passengers:
		if is_instance_valid(p) and p.state == passenger_scene.State.INSIDE_TRAIN:
			alighting_candidates.append(p)
	# Also check platform_passengers that might have boarded (shouldn't happen but safety check)
	for p in platform_passengers:
		if is_instance_valid(p) and p.state == passenger_scene.State.INSIDE_TRAIN:
			if is_instance_valid(p.current_train) and p.current_train == connected_train:
				alighting_candidates.append(p)
				
	# Choose a random number of passengers (5 to 12) to alight
	var target_alight_count = randi_range(5, 12)
	var alighted_from_cabin = 0
	
	if not alighting_candidates.is_empty():
		alighting_candidates.shuffle()
		var count_to_alight = min(alighting_candidates.size(), target_alight_count)
		for j in range(count_to_alight):
			var p = alighting_candidates[j]
			# Find a door on the current station's side (prefer same car's door)
			var nearest_door = null
			var best_score = INF
			var ref_car = p.current_car if is_instance_valid(p.current_car) else null
			for di in range(doors.size()):
				var door = doors[di]
				# Prefer door from same car (score 0), otherwise score 5 + spread
				var score = 0.0 if (ref_car and door.car == ref_car) else 5.0 + (j % doors.size())
				if score < best_score:
					best_score = score
					nearest_door = door
			if not nearest_door and not doors.is_empty():
				nearest_door = doors[j % doors.size()]
			if nearest_door:
				p.start_alighting(nearest_door.position, nearest_door.car)
				if not train_passengers.has(p):
					train_passengers.append(p)
				alighted_from_cabin += 1
				
	# If we need more alighting passengers (cabin was empty or low), spawn new ones
	var spawn_needed = target_alight_count - alighted_from_cabin
	if spawn_needed > 0:
		var main_scene = get_tree().current_scene
		for i in range(spawn_needed):
			# Select a random door directly - no need to pick a car
			if doors.is_empty():
				break
			var door = doors[randi() % doors.size()]
			
			var p = Node3D.new()
			p.set_script(passenger_scene)
			main_scene.add_child(p)
			p.original_waiting_pos = door.position
			
			# Spawn and immediately start alighting (appear near door, walk out)
			p.start_alighting(door.position, door.car)
			train_passengers.append(p)

func _on_train_doors_closed():
	if not last_station:
		return
		
	# Verify horn rule before close
	if not horn_blown_before_close:
		GameManager.add_money(-20)
		_show_hud_warning("VI PHẠM:\nKHÔNG BẤM CÒI CẢNH BÁO\nTRƯỚC KHI ĐÓNG CỬA! -20$")
		
	# Abort boarding for any platform passengers still walking or queuing
	for p in platform_passengers:
		if is_instance_valid(p) and p.state in [passenger_scene.State.WALKING_TO_DOOR, passenger_scene.State.QUEUING]:
			p.abort_boarding()
			
	# Clear queues
	door_queues.clear()
			
	# Show summary message
	var hud = get_node_or_null("/root/Main/HUD")
	if hud:
		var total_reward = boarded_count * 25 + alighted_count * 15
		hud.show_message("Đón trả khách ga " + last_station.station_name + ":\n- Đón: " + str(boarded_count) + " khách (+$" + str(boarded_count * 25) + ")\n- Trả: " + str(alighted_count) + " khách (+$" + str(alighted_count * 15) + ")")

func passenger_boarded(passenger: Node3D):
	boarded_count += 1
	GameManager.add_money(25)
	platform_passengers.erase(passenger)
	# Track this passenger as being inside the train
	if not train_passengers.has(passenger):
		train_passengers.append(passenger)
	
	# Cap total train passengers to avoid memory buildup (max 40 invisible passengers)
	var inside_count = 0
	for p in train_passengers:
		if is_instance_valid(p) and p.state == passenger_scene.State.INSIDE_TRAIN:
			inside_count += 1
	if inside_count > 40:
		passenger.queue_free() # Let them disappear if train is full

func passenger_alighted(passenger: Node3D):
	alighted_count += 1
	GameManager.add_money(15)
	train_passengers.erase(passenger)
	# Note: Passenger transitions to State.WALKING_AWAY, handles its own cleanup

func _show_hud_warning(msg: String):
	var hud = get_node_or_null("/root/Main/HUD")
	if hud:
		if hud.has_method("show_big_warning"):
			hud.show_big_warning(msg, true)
		elif hud.has_method("show_message"):
			hud.show_message(msg)

# Returns {car_node: passenger_count} for all cars in connected_train
func get_passengers_per_car() -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(connected_train):
		return result
	# Initialize all cars to 0
	for car in connected_train.cars:
		result[car] = 0
	# Count INSIDE_TRAIN passengers by their current_car
	for p in train_passengers:
		if is_instance_valid(p) and p.state == passenger_scene.State.INSIDE_TRAIN:
			var car = p.current_car
			if is_instance_valid(car) and result.has(car):
				result[car] += 1
			else:
				# Passenger has no car ref but is INSIDE_TRAIN - distribute evenly
				# Assign to car1 as fallback
				if is_instance_valid(connected_train.car1) and result.has(connected_train.car1):
					result[connected_train.car1] += 1
	return result

# Returns total number of invisible passengers currently inside the train
func get_total_train_passengers() -> int:
	var count = 0
	for p in train_passengers:
		if is_instance_valid(p) and p.state == passenger_scene.State.INSIDE_TRAIN:
			count += 1
	return count
