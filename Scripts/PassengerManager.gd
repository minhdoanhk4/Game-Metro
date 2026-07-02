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
		_spawn_platform_passengers(s, randi_range(50, 120))

func _spawn_platform_passengers(station: Node, count: int):
	var side = station.platform_side
	var platform_y = _get_platform_top_y(station)
	
	for i in range(count):
		var p = Node3D.new()
		p.name = "Passenger_" + str(randi())
		p.set_script(passenger_scene)
		
		# Determine safe X spawn on the platform (away from track edge)
		var safe_x = 0.0
		var spawn_side = side
		if side == 0:
			spawn_side = -1 if randf() > 0.5 else 1
			
		if spawn_side == -1:
			safe_x = randf_range(2.5, 4.5)
		else:
			safe_x = randf_range(-4.5, -2.5)
			
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
	var waiting_passengers = []
	for p in platform_passengers:
		if is_instance_valid(p) and p.current_station == station and p.state == p.State.WANDERING:
			waiting_passengers.append(p)
			
	waiting_passengers.shuffle()
	var board_count = mini(randi_range(5, 100), waiting_passengers.size())
	
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
	var alight_count = randi_range(5, 100)
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
		
		# Walk out onto the platform (away from track)
		var plat_node = station.get_node_or_null("Platform")
		var safe_x = 3.5
		if plat_node:
			safe_x = plat_node.position.x
		elif station.platform_side == 1:
			safe_x = -3.5
		
		var target_global_x = station.to_global(Vector3(safe_x, 0, 0)).x
		p.alight_to(target_global_x)
		platform_passengers.append(p)

func _on_doors_closed(train: Node):
	# Cancel boarding for those who haven't made it
	for p in platform_passengers:
		if is_instance_valid(p) and p.state == p.State.GOING_TO_DOOR:
			p.state = p.State.WANDERING
			if randf() > 0.5:
				p.velocity = Vector3(0, 0, p.walk_speed)
			else:
				p.velocity = Vector3(0, 0, -p.walk_speed)

func passenger_boarded(passenger: Node3D, destroy: bool = true):
	platform_passengers.erase(passenger)
	total_boarded_count += 1
	if destroy:
		passenger.queue_free()
	
func get_total_train_passengers() -> int:
	return total_boarded_count
