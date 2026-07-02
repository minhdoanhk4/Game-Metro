extends Node3D

enum State {
	WANDERING,
	GOING_TO_DOOR,
	ALIGHTING,
	BOARDED
}

var state: State = State.WANDERING
var substate: String = ""

var walk_speed: float = 1.5
var target_door_pos: Vector3 = Vector3.ZERO
var target_entry_x: float = 0.0
var target_x: float = 0.0
var target_car: Node3D = null

var station_bounds_z: Vector2 = Vector2(-70, 70)
var current_station: Node3D = null

var velocity: Vector3 = Vector3(0, 0, walk_speed)

var walk_cycle: float = 0.0
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var body_mesh: CSGBox3D

func _ready():
	_create_humanoid()
	
	# Randomize color
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(randf(), randf(), randf())
	body_mesh.material = mat
	
	# Randomize start direction
	if randf() > 0.5:
		velocity.z = -walk_speed
		
	# Slight speed variation
	walk_speed += randf_range(-0.3, 0.3)
	velocity = velocity.normalized() * walk_speed

func _create_humanoid():
	# Body
	body_mesh = CSGBox3D.new()
	body_mesh.size = Vector3(0.4, 0.6, 0.25)
	body_mesh.position = Vector3(0, 0.8, 0)
	add_child(body_mesh)
	
	# Head
	var head = CSGSphere3D.new()
	head.radius = 0.15
	head.position = Vector3(0, 1.25, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.9, 0.75, 0.6) # Skin color
	head.material = head_mat
	add_child(head)
	
	# Limbs factory
	var make_limb = func(pos: Vector3, is_arm: bool):
		var limb = CSGCylinder3D.new()
		limb.radius = 0.08
		limb.height = 0.5 if is_arm else 0.6
		
		var pivot = Node3D.new()
		pivot.position = pos
		add_child(pivot)
		
		limb.position = Vector3(0, -limb.height/2.0, 0)
		var limb_mat = StandardMaterial3D.new()
		if is_arm:
			limb_mat.albedo_color = Color(0.8, 0.8, 0.8) # Sleeves
		else:
			limb_mat.albedo_color = Color(0.2, 0.2, 0.3) # Pants
		limb.material = limb_mat
		pivot.add_child(limb)
		return pivot
		
	left_arm = make_limb.call(Vector3(-0.28, 1.05, 0), true)
	right_arm = make_limb.call(Vector3(0.28, 1.05, 0), true)
	left_leg = make_limb.call(Vector3(-0.12, 0.5, 0), false)
	right_leg = make_limb.call(Vector3(0.12, 0.5, 0), false)

func _process(delta):
	if state == State.BOARDED and substate != "DISPERSE":
		return
		
	_animate_walk(delta)
	
	if state == State.WANDERING:
		_process_wandering(delta)
	elif state == State.GOING_TO_DOOR:
		_process_going_to_door(delta)
	elif state == State.ALIGHTING:
		_process_alighting(delta)
	elif state == State.BOARDED and substate == "DISPERSE":
		_process_boarded(delta)

func _process_boarded(delta):
	var dir = target_door_pos - position
	dir.y = 0
	var dist = dir.length()
	
	if dist < 0.1:
		substate = "IDLE"
		velocity = Vector3.ZERO
		left_arm.rotation.x = 0.0
		right_arm.rotation.x = 0.0
		left_leg.rotation.x = 0.0
		right_leg.rotation.x = 0.0
	else:
		velocity = dir.normalized() * walk_speed
		position += velocity * delta

func _animate_walk(delta):
	var is_moving = velocity.length() > 0.1
	if is_moving:
		walk_cycle += delta * walk_speed * 4.0
		var angle = sin(walk_cycle) * 0.6
		left_arm.rotation.x = angle
		right_arm.rotation.x = -angle
		left_leg.rotation.x = -angle
		right_leg.rotation.x = angle
		
		# Rotate whole body to face velocity direction
		var target_angle = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 15.0)
	else:
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, delta * 10.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 10.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 10.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 10.0)

func _process_wandering(delta):
	global_position += velocity * delta
	
	if current_station:
		var local_z = current_station.to_local(global_position).z
		if local_z < station_bounds_z.x:
			velocity = Vector3(0, 0, walk_speed)
		elif local_z > station_bounds_z.y:
			velocity = Vector3(0, 0, -walk_speed)

func assign_door(door_pos: Vector3, inside_x: float, car: Node3D = null):
	target_door_pos = door_pos
	target_entry_x = inside_x
	target_car = car
	state = State.GOING_TO_DOOR
	substate = "ALIGN_Z"
	if target_door_pos.z > global_position.z:
		velocity = Vector3(0, 0, walk_speed)
	else:
		velocity = Vector3(0, 0, -walk_speed)

func _process_going_to_door(delta):
	if substate == "ALIGN_Z":
		global_position += velocity * delta
		# Check if we passed the door's Z
		if (velocity.z > 0 and global_position.z >= target_door_pos.z) or (velocity.z < 0 and global_position.z <= target_door_pos.z):
			global_position.z = target_door_pos.z
			substate = "ENTER_X"
			if target_entry_x > global_position.x:
				velocity = Vector3(walk_speed, 0, 0)
			else:
				velocity = Vector3(-walk_speed, 0, 0)
	elif substate == "ENTER_X":
		global_position += velocity * delta
		var dist_x = abs(global_position.x - target_entry_x)
		if dist_x < 0.2: # Boarded
			state = State.BOARDED
			substate = "DISPERSE"
			
			if target_car != null and is_instance_valid(target_car):
				var global_pos = global_position
				var global_rot = global_rotation
				var p = get_parent()
				if p:
					p.remove_child(self)
				target_car.add_child(self)
				global_position = global_pos
				global_rotation = global_rot
				
				# Generate random local target position inside the train car (avoid cabin at -Z)
				target_door_pos = Vector3(randf_range(-0.8, 0.8), position.y, randf_range(-6.5, 8.5))
				
				var train = target_car.get_parent()
				if train and "passenger_count" in train:
					train.passenger_count += 1
					if train.is_player_controlled:
						if GameManager:
							GameManager.add_money(10)
			
			var pm = get_node_or_null("/root/Main/PassengerManager")
			if pm:
				pm.passenger_boarded(self, false)

func alight_to(target_x_pos: float):
	state = State.ALIGHTING
	target_x = target_x_pos
	if target_x > global_position.x:
		velocity = Vector3(walk_speed, 0, 0)
	else:
		velocity = Vector3(-walk_speed, 0, 0)

func _process_alighting(delta):
	global_position += velocity * delta
	if (velocity.x > 0 and global_position.x >= target_x) or (velocity.x < 0 and global_position.x <= target_x):
		global_position.x = target_x
		state = State.WANDERING
		if randf() > 0.5:
			velocity = Vector3(0, 0, walk_speed)
		else:
			velocity = Vector3(0, 0, -walk_speed)
