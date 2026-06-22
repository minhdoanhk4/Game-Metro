extends Node3D
class_name Passenger

enum State {
	WAITING,
	WALKING_TO_DOOR,
	QUEUING,
	BOARDING,
	INSIDE_TRAIN,
	ALIGHTING,
	WALKING_AWAY
}

var state: State = State.WAITING
var target_pos: Vector3 = Vector3.ZERO
var target_door_pos: Vector3 = Vector3.ZERO
var speed: float = 2.5
var original_waiting_pos: Vector3 = Vector3.ZERO
var current_train: Train = null
var current_car: Node3D = null
var target_door_index: int = -1

var left_hip: Node3D
var right_hip: Node3D
var left_shoulder: Node3D
var right_shoulder: Node3D
var left_shin: Node3D
var right_shin: Node3D
var left_elbow: Node3D
var right_elbow: Node3D
var materials: Array[StandardMaterial3D] = []

var is_wandering: bool = false
var wander_timer: float = 0.0

func _ready():
	# Randomize scale for variety (adults, some children)
	var is_child = randf() < 0.1
	var char_scale = randf_range(0.55, 0.65) if is_child else randf_range(0.9, 1.05)
	scale = Vector3(char_scale, char_scale, char_scale)
	
	# Offset start wander timer so they don't move in sync
	wander_timer = randf_range(0.1, 5.0)
	
	# Determine gender/body type for clothed persons
	var is_female = randf() < 0.5
	var has_skirt = is_female and (randf() < 0.5)
	var has_shorts = not has_skirt and (randf() < 0.3)
	
	# Choose style (Casual Clothed vs Solid Mannequin)
	var style_mannequin = randf() < 0.25
	
	# Create materials with flat matte shading (Minecraft style)
	var mat_skin = StandardMaterial3D.new()
	mat_skin.flat_shading = true
	var skin_colors = [
		Color(0.95, 0.80, 0.70), # Peach
		Color(0.82, 0.62, 0.48), # Tan
		Color(0.60, 0.42, 0.28), # Brown
		Color(0.42, 0.28, 0.18), # Dark brown
		Color(0.98, 0.86, 0.76)  # Pale
	]
	mat_skin.albedo_color = skin_colors[randi() % skin_colors.size()]
	mat_skin.roughness = 1.0
	mat_skin.specular = 0.0
	mat_skin.metallic = 0.0
	materials.append(mat_skin)
	
	var mat_shirt = StandardMaterial3D.new()
	mat_shirt.flat_shading = true
	var shirt_colors = [
		Color(0.9, 0.2, 0.2), # Red
		Color(0.2, 0.7, 0.3), # Green
		Color(0.2, 0.5, 0.9), # Blue
		Color(0.9, 0.8, 0.1), # Yellow
		Color(0.1, 0.8, 0.8), # Cyan
		Color(0.8, 0.1, 0.8), # Magenta
		Color(0.9, 0.5, 0.1), # Orange
		Color(0.5, 0.2, 0.8), # Purple
		Color(0.95, 0.95, 0.95), # White
		Color(0.15, 0.15, 0.15)  # Black
	]
	mat_shirt.albedo_color = shirt_colors[randi() % shirt_colors.size()]
	mat_shirt.roughness = 1.0
	mat_shirt.specular = 0.0
	mat_shirt.metallic = 0.0
	materials.append(mat_shirt)
	
	var mat_pants = StandardMaterial3D.new()
	mat_pants.flat_shading = true
	var pants_colors = [
		Color(0.15, 0.25, 0.45), # Denim Blue
		Color(0.25, 0.25, 0.25), # Dark Grey
		Color(0.45, 0.40, 0.35), # Khaki
		Color(0.35, 0.25, 0.20), # Brown
		Color(0.12, 0.12, 0.12)  # Black
	]
	mat_pants.albedo_color = pants_colors[randi() % pants_colors.size()]
	mat_pants.roughness = 1.0
	mat_pants.specular = 0.0
	mat_pants.metallic = 0.0
	materials.append(mat_pants)
	
	var mat_shoes = StandardMaterial3D.new()
	mat_shoes.flat_shading = true
	var shoe_colors = [Color(0.1, 0.1, 0.1), Color(0.9, 0.9, 0.9), Color(0.4, 0.25, 0.15)]
	mat_shoes.albedo_color = shoe_colors[randi() % shoe_colors.size()]
	mat_shoes.roughness = 1.0
	mat_shoes.specular = 0.0
	mat_shoes.metallic = 0.0
	materials.append(mat_shoes)
	
	var mat_hair = StandardMaterial3D.new()
	mat_hair.flat_shading = true
	var hair_colors = [
		Color(0.1, 0.1, 0.1),    # Black
		Color(0.3, 0.2, 0.15),   # Dark Brown
		Color(0.5, 0.35, 0.2),   # Light Brown
		Color(0.85, 0.7, 0.3),   # Blonde
		Color(0.7, 0.3, 0.15)    # Redhead
	]
	mat_hair.albedo_color = hair_colors[randi() % hair_colors.size()]
	mat_hair.roughness = 1.0
	mat_hair.specular = 0.0
	mat_hair.metallic = 0.0
	materials.append(mat_hair)

	if style_mannequin:
		var mat_mono = StandardMaterial3D.new()
		mat_mono.flat_shading = true
		var mannequin_colors = [
			Color(0.95, 0.45, 0.1),  # Orange
			Color(0.9, 0.1, 0.5),   # Pink/Magenta
			Color(0.1, 0.7, 0.8),   # Teal/Cyan
			Color(0.9, 0.8, 0.1),   # Yellow
			Color(0.6, 0.2, 0.8),   # Purple
			Color(0.8, 0.8, 0.8),   # Silver/Grey
			Color(0.7, 0.5, 0.3),   # Bronze/Brown
			Color(0.1, 0.8, 0.4)    # Green
		]
		mat_mono.albedo_color = mannequin_colors[randi() % mannequin_colors.size()]
		mat_mono.roughness = 1.0
		mat_mono.specular = 0.0
		mat_mono.metallic = 0.0
		
		materials.clear()
		mat_skin = mat_mono
		mat_shirt = mat_mono
		mat_pants = mat_mono
		mat_shoes = mat_mono
		mat_hair = mat_mono
		materials.append(mat_mono)

	# Container for relative rotation
	var model = Node3D.new()
	model.name = "Model"
	add_child(model)
	
	# Torso (Chest/Shirt) - Minecraft boxy style
	var torso = MeshInstance3D.new()
	var torso_mesh = BoxMesh.new()
	if style_mannequin:
		torso_mesh.size = Vector3(0.24, 0.36, 0.12)
	else:
		torso_mesh.size = Vector3(0.20 if is_female else 0.24, 0.36, 0.11 if is_female else 0.12)
	torso.mesh = torso_mesh
	torso.material_override = mat_shirt
	torso.position.y = 0.95 # Height from floor
	model.add_child(torso)
	
	# Pelvis (Pants top/hips) - Boxy style
	var pelvis = MeshInstance3D.new()
	var pelvis_mesh = BoxMesh.new()
	pelvis_mesh.size = Vector3(torso_mesh.size.x, 0.08, torso_mesh.size.z)
	pelvis.mesh = pelvis_mesh
	pelvis.material_override = mat_pants
	pelvis.position = Vector3(0.0, -0.22, 0.0) # torso bottom is -0.18
	torso.add_child(pelvis)
	
	# Optional Skirt - Boxy style
	if has_skirt and not style_mannequin:
		var skirt = MeshInstance3D.new()
		var skirt_mesh = BoxMesh.new()
		skirt_mesh.size = Vector3(torso_mesh.size.x * 1.1, 0.24, torso_mesh.size.z * 1.1)
		skirt.mesh = skirt_mesh
		skirt.material_override = mat_pants
		skirt.position = Vector3(0.0, -0.12, 0.0)
		pelvis.add_child(skirt)
		
	# Neck - Boxy
	var neck = MeshInstance3D.new()
	var neck_mesh = BoxMesh.new()
	neck_mesh.size = Vector3(0.08, 0.06, 0.08)
	neck.mesh = neck_mesh
	neck.material_override = mat_skin
	neck.position = Vector3(0.0, 0.21, 0.0) # torso top is at 0.18
	torso.add_child(neck)
	
	# Head - Boxy (Steve/Alex style)
	var head = MeshInstance3D.new()
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.18, 0.18, 0.18)
	head.mesh = head_mesh
	head.material_override = mat_skin
	head.position = Vector3(0.0, 0.12, 0.0) # neck center is at 0, top is at 0.03
	neck.add_child(head)
	
	# Hair Cap & Styles - Boxy
	if not style_mannequin:
		var hair_style = randi() % 5
		
		if hair_style == 0 or hair_style == 1 or hair_style == 2:
			var hair_cap = MeshInstance3D.new()
			var hc_mesh = BoxMesh.new()
			hc_mesh.size = Vector3(0.19, 0.10, 0.19)
			hair_cap.mesh = hc_mesh
			hair_cap.material_override = mat_hair
			hair_cap.position = Vector3(0.0, 0.05, -0.01)
			head.add_child(hair_cap)
			
			if hair_style == 1:
				var ponytail = MeshInstance3D.new()
				var pt_mesh = BoxMesh.new()
				pt_mesh.size = Vector3(0.06, 0.16, 0.06)
				ponytail.mesh = pt_mesh
				ponytail.material_override = mat_hair
				ponytail.position = Vector3(0.0, -0.07, -0.10)
				ponytail.rotation.x = deg_to_rad(-15)
				hair_cap.add_child(ponytail)
			elif hair_style == 2:
				var bun = MeshInstance3D.new()
				var bun_mesh = BoxMesh.new()
				bun_mesh.size = Vector3(0.06, 0.06, 0.06)
				bun.mesh = bun_mesh
				bun.material_override = mat_hair
				bun.position = Vector3(0.0, 0.07, -0.07)
				hair_cap.add_child(bun)
				
		elif hair_style == 3:
			var cap_dome = MeshInstance3D.new()
			var cd_mesh = BoxMesh.new()
			cd_mesh.size = Vector3(0.19, 0.08, 0.19)
			cap_dome.mesh = cd_mesh
			
			var mat_cap = StandardMaterial3D.new()
			mat_cap.flat_shading = true
			mat_cap.albedo_color = Color(randf_range(0.1, 0.9), randf_range(0.1, 0.9), randf_range(0.1, 0.9))
			mat_cap.roughness = 1.0
			mat_cap.specular = 0.0
			mat_cap.metallic = 0.0
			materials.append(mat_cap)
			
			cap_dome.material_override = mat_cap
			cap_dome.position = Vector3(0.0, 0.06, -0.01)
			head.add_child(cap_dome)
			
			var cap_bill = MeshInstance3D.new()
			var cb_mesh = BoxMesh.new()
			cb_mesh.size = Vector3(0.19, 0.015, 0.08)
			cap_bill.mesh = cb_mesh
			cap_bill.material_override = mat_cap
			cap_bill.position = Vector3(0.0, -0.02, 0.08)
			cap_bill.rotation.x = deg_to_rad(5)
			cap_dome.add_child(cap_bill)
	else:
		# Solid mannequin hair cap for styling
		var hair_cap = MeshInstance3D.new()
		var hc_mesh = BoxMesh.new()
		hc_mesh.size = Vector3(0.19, 0.10, 0.19)
		hair_cap.mesh = hc_mesh
		hair_cap.material_override = mat_hair
		hair_cap.position = Vector3(0.0, 0.05, -0.01)
		head.add_child(hair_cap)

	# Shared limb meshes (Boxy)
	var thigh_mesh = BoxMesh.new()
	thigh_mesh.size = Vector3(0.11, 0.18, 0.11)
	
	var shin_mesh = BoxMesh.new()
	shin_mesh.size = Vector3(0.10, 0.18, 0.10)
	
	var foot_mesh = BoxMesh.new()
	foot_mesh.size = Vector3(0.10, 0.05, 0.14)

	# Left Hip / Thigh / Shin / Foot (Boxy structure, no joint spheres)
	left_hip = Node3D.new()
	left_hip.name = "LeftHip"
	left_hip.position = Vector3(-0.065, -0.04, 0.0)
	pelvis.add_child(left_hip)
	
	var left_thigh = MeshInstance3D.new()
	left_thigh.mesh = thigh_mesh
	var mat_thigh = mat_pants
	if not style_mannequin:
		if has_skirt:
			mat_thigh = mat_skin
		elif has_shorts:
			mat_thigh = mat_pants
	left_thigh.material_override = mat_thigh
	left_thigh.position = Vector3(0.0, -0.09, 0.0) # pivot is at top of thigh
	left_hip.add_child(left_thigh)
	
	left_shin = Node3D.new()
	left_shin.name = "LeftShin"
	left_shin.position = Vector3(0.0, -0.18, 0.0) # knee joint at bottom of thigh
	left_thigh.add_child(left_shin)
	
	var left_shin_mesh_inst = MeshInstance3D.new()
	left_shin_mesh_inst.mesh = shin_mesh
	var mat_shin = mat_pants
	if not style_mannequin:
		if has_skirt or has_shorts:
			mat_shin = mat_skin
	left_shin_mesh_inst.material_override = mat_shin
	left_shin_mesh_inst.position = Vector3(0.0, -0.09, 0.0)
	left_shin.add_child(left_shin_mesh_inst)
	
	var left_foot = MeshInstance3D.new()
	left_foot.mesh = foot_mesh
	left_foot.material_override = mat_shoes
	left_foot.position = Vector3(0.0, -0.205, 0.02) # ankle joint is at -0.18
	left_shin.add_child(left_foot)

	# Right Hip / Thigh / Shin / Foot
	right_hip = Node3D.new()
	right_hip.name = "RightHip"
	right_hip.position = Vector3(0.07, -0.05, 0.0)
	pelvis.add_child(right_hip)
	
	var right_thigh = MeshInstance3D.new()
	right_thigh.mesh = thigh_mesh
	right_thigh.material_override = mat_thigh
	right_thigh.position = Vector3(0.0, -0.09, 0.0)
	right_hip.add_child(right_thigh)
	
	right_shin = Node3D.new()
	right_shin.name = "RightShin"
	right_shin.position = Vector3(0.0, -0.18, 0.0)
	right_thigh.add_child(right_shin)
	
	var right_shin_mesh_inst = MeshInstance3D.new()
	right_shin_mesh_inst.mesh = shin_mesh
	right_shin_mesh_inst.material_override = mat_shin
	right_shin_mesh_inst.position = Vector3(0.0, -0.09, 0.0)
	right_shin.add_child(right_shin_mesh_inst)
	
	var right_foot = MeshInstance3D.new()
	right_foot.mesh = foot_mesh
	right_foot.material_override = mat_shoes
	right_foot.position = Vector3(0.0, -0.205, 0.02)
	right_shin.add_child(right_foot)

	# Left Shoulder / Arm / Forearm (Boxy)
	var shoulder_offset_x = -0.17 if not is_female else -0.14
	if style_mannequin:
		shoulder_offset_x = -0.16
		
	left_shoulder = Node3D.new()
	left_shoulder.name = "LeftShoulder"
	left_shoulder.position = Vector3(shoulder_offset_x, 0.12, 0.0)
	torso.add_child(left_shoulder)
	
	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.10, 0.18, 0.10)
	
	var left_arm = MeshInstance3D.new()
	left_arm.mesh = arm_mesh
	left_arm.material_override = mat_shirt
	left_arm.position = Vector3(0.0, -0.09, 0.0) # pivot is at top
	left_shoulder.add_child(left_arm)
	
	left_elbow = Node3D.new()
	left_elbow.name = "LeftElbow"
	left_elbow.position = Vector3(0.0, -0.18, 0.0)
	left_arm.add_child(left_elbow)
	
	var forearm_mesh = BoxMesh.new()
	forearm_mesh.size = Vector3(0.09, 0.18, 0.09)
	
	var left_forearm = MeshInstance3D.new()
	left_forearm.mesh = forearm_mesh
	left_forearm.material_override = mat_skin
	left_forearm.position = Vector3(0.0, -0.09, 0.0)
	left_elbow.add_child(left_forearm)
	
	var hand_mesh = BoxMesh.new()
	hand_mesh.size = Vector3(0.09, 0.05, 0.09)
	
	var left_hand = MeshInstance3D.new()
	left_hand.mesh = hand_mesh
	left_hand.material_override = mat_skin
	left_hand.position = Vector3(0.0, -0.20, 0.0)
	left_elbow.add_child(left_hand)

	# Right Shoulder / Arm / Forearm
	right_shoulder = Node3D.new()
	right_shoulder.name = "RightShoulder"
	right_shoulder.position = Vector3(-shoulder_offset_x, 0.12, 0.0)
	torso.add_child(right_shoulder)
	
	var right_arm = MeshInstance3D.new()
	right_arm.mesh = arm_mesh
	right_arm.material_override = mat_shirt
	right_arm.position = Vector3(0.0, -0.09, 0.0)
	right_shoulder.add_child(right_arm)
	
	right_elbow = Node3D.new()
	right_elbow.name = "RightElbow"
	right_elbow.position = Vector3(0.0, -0.18, 0.0)
	right_arm.add_child(right_elbow)
	
	var right_forearm = MeshInstance3D.new()
	right_forearm.mesh = forearm_mesh
	right_forearm.material_override = mat_skin
	right_forearm.position = Vector3(0.0, -0.09, 0.0)
	right_elbow.add_child(right_forearm)
	
	var right_hand = MeshInstance3D.new()
	right_hand.mesh = hand_mesh
	right_hand.material_override = mat_skin
	right_hand.position = Vector3(0.0, -0.20, 0.0)
	right_elbow.add_child(right_hand)

func _process(delta):
	# Don't process logic when paused
	if get_tree().paused:
		return

	# Animate walking cycle if moving
	var is_moving = state in [State.WALKING_TO_DOOR, State.ALIGHTING, State.WALKING_AWAY] or is_wandering
	if is_moving:
		var time_scale = 5.5 * speed
		var angle = sin(Time.get_ticks_msec() * 0.001 * time_scale) * 0.6
		
		if left_hip: left_hip.rotation.x = angle
		if right_hip: right_hip.rotation.x = -angle
		if left_shoulder: left_shoulder.rotation.x = -angle * 0.7
		if right_shoulder: right_shoulder.rotation.x = angle * 0.7
		
		# Animate knee and elbow bends (very cute blocky stride)
		if left_shin: left_shin.rotation.x = abs(angle) * 0.4
		if right_shin: right_shin.rotation.x = abs(angle) * 0.4
		if left_elbow: left_elbow.rotation.x = -0.15 - abs(angle) * 0.25
		if right_elbow: right_elbow.rotation.x = -0.15 - abs(angle) * 0.25
	else:
		# Reset to standing pose
		if left_hip: left_hip.rotation.x = move_toward(left_hip.rotation.x, 0.0, delta * 5.0)
		if right_hip: right_hip.rotation.x = move_toward(right_hip.rotation.x, 0.0, delta * 5.0)
		if left_shoulder: left_shoulder.rotation.x = move_toward(left_shoulder.rotation.x, 0.0, delta * 5.0)
		if right_shoulder: right_shoulder.rotation.x = move_toward(right_shoulder.rotation.x, 0.0, delta * 5.0)
		if left_shin: left_shin.rotation.x = move_toward(left_shin.rotation.x, 0.0, delta * 5.0)
		if right_shin: right_shin.rotation.x = move_toward(right_shin.rotation.x, 0.0, delta * 5.0)
		if left_elbow: left_elbow.rotation.x = move_toward(left_elbow.rotation.x, -0.15, delta * 5.0)
		if right_elbow: right_elbow.rotation.x = move_toward(right_elbow.rotation.x, -0.15, delta * 5.0)

	match state:
		State.WAITING:
			# Persistent idle wandering
			if not is_wandering:
				wander_timer -= delta
				if wander_timer <= 0.0:
					# Pick a random target within a small rectangle around spawn point
					var wander_range_x = 0.6
					var wander_range_z = 8.0
					target_pos = original_waiting_pos + Vector3(randf_range(-wander_range_x, wander_range_x), 0.0, randf_range(-wander_range_z, wander_range_z))
					is_wandering = true
					speed = randf_range(0.5, 0.8) # Slow idle walk speed
			else:
				_move_towards_target(delta)
				if global_position.distance_to(target_pos) < 0.2:
					is_wandering = false
					wander_timer = randf_range(3.0, 8.0) # Rest for 3 to 8 seconds
					
		State.WALKING_TO_DOOR:
			_move_towards_target(delta)
			if global_position.distance_to(target_pos) < 0.2:
				state = State.QUEUING
				
		State.QUEUING:
			# Stand still in queue, face the door
			var dir_to_door = (target_door_pos - global_position)
			dir_to_door.y = 0
			if dir_to_door.length() > 0.05:
				var angle = atan2(-dir_to_door.x, -dir_to_door.z)
				rotation.y = lerp_angle(rotation.y, angle, delta * 5.0)
				
		State.BOARDING:
			# Immediately become invisible - passenger is now "inside" the train
			visible = false
			state = State.INSIDE_TRAIN
			# Notify the PassengerManager of successful boarding
			var pm = get_node_or_null("/root/Main/PassengerManager")
			if pm:
				pm.passenger_boarded(self)
					
		State.INSIDE_TRAIN:
			# Stay invisible inside the train - we only track the count
			# Free if passenger has no valid train or car reference (orphaned)
			if not is_instance_valid(current_train) and not is_instance_valid(current_car):
				queue_free()
				
		State.ALIGHTING:
			# Walk to door target in global space then disperse
			_move_towards_target(delta)
			if global_position.distance_to(target_pos) < 0.3:
				state = State.WALKING_AWAY
				# Dispersal point: step further onto the platform, walk along the Z-axis
				var dir_platform = Vector3.ZERO
				if is_instance_valid(current_car):
					var train_x = current_car.global_position.x
					dir_platform = Vector3(1.0, 0.0, 0.0) if global_position.x > train_x else Vector3(-1.0, 0.0, 0.0)
				else:
					dir_platform = Vector3(1.0, 0.0, 0.0) if global_position.x > 0 else Vector3(-1.0, 0.0, 0.0)
				target_pos = global_position + dir_platform * 2.0 + Vector3(0.0, 0.0, (1.0 if randf() < 0.5 else -1.0) * randf_range(10.0, 25.0))
				speed = randf_range(1.0, 1.2)
				# Notify PassengerManager
				var pm = get_node_or_null("/root/Main/PassengerManager")
				if pm:
					pm.passenger_alighted(self)
					
		State.WALKING_AWAY:
			_move_towards_target(delta)
			# Fade out all materials
			var all_invisible = true
			for m in materials:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color.a = move_toward(m.albedo_color.a, 0.0, delta * 1.5)
				if m.albedo_color.a > 0.05:
					all_invisible = false
			if global_position.distance_to(target_pos) < 0.3 or all_invisible:
				queue_free()

func _move_towards_target(delta):
	var dir = (target_pos - global_position)
	dir.y = 0 # keep on flat floor
	if dir.length() > 0.05:
		dir = dir.normalized()
		global_position += dir * speed * delta
		# Rotate to face walking direction smoothly
		var angle = atan2(-dir.x, -dir.z)
		rotation.y = angle

func go_to_queue(door_pos: Vector3, queue_dir: Vector3, queue_idx: int, train: Train, car: Node3D):
	current_train = train
	current_car = car
	target_door_pos = door_pos
	target_pos = door_pos + queue_dir * (1.2 + queue_idx * 0.8)
	state = State.WALKING_TO_DOOR
	is_wandering = false
	speed = randf_range(1.0, 1.2)

func update_queue_index(queue_dir: Vector3, queue_idx: int):
	target_pos = target_door_pos + queue_dir * (1.2 + queue_idx * 0.8)
	if state == State.QUEUING:
		state = State.WALKING_TO_DOOR

func start_boarding():
	# Just hide the passenger - they're now "inside" the train (impression mode)
	# No complex reparenting needed - avoids passengers floating on tracks
	state = State.BOARDING
	is_wandering = false

func start_alighting(global_door_pos: Vector3, car: Node3D):
	# Appear near the door and walk away onto platform
	visible = true
	current_car = car
	global_position = global_door_pos + Vector3(0.0, 0.5, 0.0)
	target_pos = global_door_pos
	state = State.ALIGHTING
	is_wandering = false
	speed = randf_range(1.0, 1.2)
	
func abort_boarding():
	if state in [State.WALKING_TO_DOOR, State.QUEUING]:
		# Turn around and go back to original waiting position to stay on platform
		target_pos = original_waiting_pos
		state = State.WAITING
		is_wandering = false
		speed = randf_range(0.5, 0.8) # Reset to slow wander speed
		current_train = null
		current_car = null
