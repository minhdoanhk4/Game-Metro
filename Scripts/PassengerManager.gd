extends Node

var passenger_scene = preload("res://Scripts/Passenger.gd")
var platform_passengers: Array = []
var total_boarded_count: int = 0

var stations: Array = []
var connected_trains: Array = []

func _ready():
	stations = get_tree().get_nodes_in_group("stations")
	call_deferred("_spawn_initial_passengers")

func _process(_delta):
	# Continuously scan for new trains and connect their signals
	var trains = get_tree().get_nodes_in_group("train")
	for t in trains:
		if is_instance_valid(t) and not connected_trains.has(t):
			t.connect("doors_opened", _on_doors_opened.bind(t))
			t.connect("doors_closed", _on_doors_closed.bind(t))
			connected_trains.append(t)
			if t.doors_open:
				_on_doors_opened(t)

func _get_platform_top_y(station: Node) -> float:
	var plat = station.get_node_or_null("Platform")
	if plat and plat is CSGBox3D:
		return station.global_transform.origin.y + plat.position.y + plat.size.y / 2.0
	return station.global_transform.origin.y + 1.0

func _spawn_initial_passengers():
	for s in stations:
		_spawn_platform_passengers(s, randi_range(20, 80))

func _spawn_platform_passengers(station: Node, count: int):
	var side = station.platform_side
	var platform_y = _get_platform_top_y(station)
	
	for i in range(count):
		var p = Node3D.new()
		p.name = "Passenger_" + str(randi())
		p.set_script(passenger_scene)
		
		var plat_node = station.get_node_or_null("Platform")
		if not plat_node:
			for child in station.get_children():
				if child is CSGBox3D and not "Sign" in child.name:
					plat_node = child
					break
		
		# Spawn safely within the local bounds of the platform box (or center of station)
		var safe_x = 0.0
		if plat_node:
			safe_x = plat_node.position.x + randf_range(-1.0, 1.0)
		else:
			safe_x = randf_range(-1.0, 1.0)
			
		var local_pos = Vector3(safe_x, 0, randf_range(-70, 70))
		
		station.add_child(p)
		var spawn_global = station.global_transform * local_pos
		spawn_global.y = platform_y
		p.global_transform.origin = spawn_global
		p.current_station = station
		
		platform_passengers.append(p)

func _on_doors_opened(train: Node):
	var station = train.current_station
	if not station:
		return
		
	var doors = train.get_open_door_global_positions()
	if doors.is_empty():
		return
	
	var platform_y = _get_platform_top_y(station)
		
	# 1. Trigger boarding
	if train.get("is_player_controlled") == true:
		var waiting_passengers = []
		for p in platform_passengers:
			if is_instance_valid(p) and p.current_station == station and p.state == p.State.WANDERING:
				var nearest_d = doors[0]
				var m_dist = p.global_position.distance_to(nearest_d.position)
				for d in doors:
					var d_dist = p.global_position.distance_to(d.position)
					if d_dist < m_dist:
						m_dist = d_dist
						nearest_d = d
				var local_p = station.to_local(p.global_position)
				var local_d = station.to_local(nearest_d.position)
				# Only board if the door is on the same side/platform (lateral distance < 8m)
				if abs(local_p.x - local_d.x) < 8.0:
					waiting_passengers.append(p)
				
		waiting_passengers.shuffle()
		
		var max_p = train.get("max_passengers") if "max_passengers" in train else 220
		var cur_p = train.get("passenger_count") if "passenger_count" in train else 0
		var space_left = max(0, max_p - cur_p)
		
		var board_count = mini(randi_range(5, 100), waiting_passengers.size())
		board_count = mini(board_count, space_left)
		
		for i in range(board_count):
			var p = waiting_passengers[i]
			# Find nearest door
			var nearest_door = doors[0]
			var min_dist = p.global_position.distance_to(nearest_door.position)
			for d in doors:
				var dist = p.global_position.distance_to(d.position)
				if dist < min_dist:
					min_dist = dist
					nearest_door = d
			
			var door_pos = nearest_door.position
			door_pos.y = platform_y
			
			# target interior X is the center of the car
			var interior_x = nearest_door.car.global_transform.origin.x
			p.assign_door(door_pos, interior_x, nearest_door.car)
		
	# 2. Trigger alighting
	var current_station_passengers = 0
	for p in platform_passengers:
		if is_instance_valid(p) and p.current_station == station:
			current_station_passengers += 1
			
	var alight_count = randi_range(5, 100)
	var max_allowed = 100
	if current_station_passengers + alight_count > max_allowed:
		alight_count = max(0, max_allowed - current_station_passengers)
		
	for i in range(alight_count):
		var door = doors[randi() % doors.size()]
		var p = Node3D.new()
		p.name = "AlightingPassenger_" + str(randi())
		p.set_script(passenger_scene)
		
		station.add_child(p)
		var interior_x = door.car.global_transform.origin.x
		var spawn_pos = door.position
		spawn_pos.x = interior_x
		spawn_pos.y = platform_y
		p.global_transform.origin = spawn_pos
		p.current_station = station
		
		# Walk out onto the platform
		var plat_node = station.get_node_or_null("Platform")
		if not plat_node:
			for child in station.get_children():
				if child is CSGBox3D and not "Sign" in child.name:
					plat_node = child
					break
		
		var safe_x = plat_node.position.x if plat_node else 0.0
		var target_global_x = station.to_global(Vector3(safe_x, 0, 0)).x + randf_range(-0.5, 0.5)
		p.alight_to(target_global_x)
		platform_passengers.append(p)

func _on_doors_closed(train: Node):
	# Cancel boarding for those who haven't made it
	for p in platform_passengers:
		if is_instance_valid(p) and p.state == p.State.GOING_TO_DOOR:
			var station = p.current_station
			if station:
				var plat_node = station.get_node_or_null("Platform")
				if not plat_node:
					for child in station.get_children():
						if child is CSGBox3D and not "Sign" in child.name:
							plat_node = child
							break
				var safe_x = plat_node.position.x if plat_node else 0.0
				var target_global_x = station.to_global(Vector3(safe_x, 0, 0)).x
				p.alight_to(target_global_x)
			else:
				p.state = p.State.WANDERING
				p.velocity = Vector3(0, 0, p.walk_speed if randf() > 0.5 else -p.walk_speed)

func passenger_boarded(passenger: Node3D, destroy: bool = true):
	platform_passengers.erase(passenger)
	total_boarded_count += 1
	if destroy:
		passenger.queue_free()
	
func get_total_train_passengers() -> int:
	return total_boarded_count
