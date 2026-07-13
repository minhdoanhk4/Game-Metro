extends Node

var mat_grass: StandardMaterial3D
var city_root: Node3D
var trees_root: Node3D
var tracks_root: Node3D
var main_scene: Node

var tree_multimeshes: Dictionary = {}
var tree_meshes: Dictionary = {}

func _init_tree_meshes():
	tree_meshes["trunk"] = CylinderMesh.new()
	tree_meshes["trunk"].top_radius = 0.12
	tree_meshes["trunk"].bottom_radius = 0.18
	tree_meshes["trunk"].height = 1.8

	tree_meshes["type0"] = SphereMesh.new()
	tree_meshes["type0"].radius = 1.0
	tree_meshes["type0"].height = 2.0

	tree_meshes["type1"] = CylinderMesh.new()
	tree_meshes["type1"].top_radius = 0.0
	tree_meshes["type1"].bottom_radius = 0.9
	tree_meshes["type1"].height = 2.4

	tree_meshes["type2"] = CapsuleMesh.new()
	tree_meshes["type2"].radius = 0.5
	tree_meshes["type2"].height = 2.2

	tree_meshes["type3_main"] = SphereMesh.new()
	tree_meshes["type3_main"].radius = 0.9
	tree_meshes["type3_main"].height = 1.6

	tree_meshes["type4"] = SphereMesh.new()
	tree_meshes["type4"].radius = 0.8
	tree_meshes["type4"].height = 1.0

func _add_tree_instance(mesh_key: String, material: Material, xform: Transform3D):
	var key = mesh_key + "_" + str(material.get_instance_id())
	if not tree_multimeshes.has(key):
		var mmi = MultiMeshInstance3D.new()
		mmi.material_override = material
		mmi.visibility_range_end = 600.0
		mmi.visibility_range_begin = 0.0
		mmi.visibility_range_end_margin = 50.0
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tree_meshes[mesh_key]
		mmi.multimesh = mm
		trees_root.add_child(mmi)
		tree_multimeshes[key] = { "mmi": mmi, "mm": mm, "transforms": [] }
	
	tree_multimeshes[key].transforms.append(xform)

func _flush_tree_multimeshes():
	for key in tree_multimeshes:
		var data = tree_multimeshes[key]
		var mm = data.mm
		var arr = data.transforms
		mm.instance_count = arr.size()
		for i in range(arr.size()):
			mm.set_instance_transform(i, arr[i])


func _ready():
	main_scene = get_parent()
	if not main_scene or not main_scene.has_node("Path3D_1"):
		main_scene = get_node_or_null("/root/Main")
	if not main_scene:
		main_scene = self
		
	var path1 = main_scene.get_node_or_null("Path3D_1")
	if not path1 or not path1.curve:
		return
		
	var curve = path1.curve
	var total_length = curve.get_baked_length()
	
	# --- Define Materials ---
	# 1. Concrete (light grey)
	var mat_concrete = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.65, 0.65, 0.68)
	mat_concrete.roughness = 0.8
	
	# 2. Blue Glass (high reflection)
	var mat_blue_glass = StandardMaterial3D.new()
	mat_blue_glass.albedo_color = Color(0.12, 0.32, 0.58)
	mat_blue_glass.metallic = 0.9
	mat_blue_glass.roughness = 0.1
	
	# 3. Transparent Canopy Glass (light cyan)
	var mat_canopy_glass = StandardMaterial3D.new()
	mat_canopy_glass.albedo_color = Color(0.7, 0.9, 1.0, 0.45)
	mat_canopy_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canopy_glass.roughness = 0.2
	
	# 4. Dark Steel
	var mat_dark_steel = StandardMaterial3D.new()
	mat_dark_steel.albedo_color = Color(0.2, 0.2, 0.22)
	mat_dark_steel.roughness = 0.6
	mat_dark_steel.metallic = 0.7
	
	# 5. Asphalt Road
	var mat_asphalt = StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.15, 0.15, 0.17)
	mat_asphalt.roughness = 0.9
	
	# 6. Yellow Emission (Windows / Lights)
	var mat_emission = StandardMaterial3D.new()
	mat_emission.albedo_color = Color(1.0, 0.9, 0.5)
	mat_emission.emission_enabled = true
	mat_emission.emission = Color(1.0, 0.9, 0.5)
	mat_emission.emission_energy_multiplier = 1.5
	
	# 7. White accent
	var mat_white = StandardMaterial3D.new()
	mat_white.albedo_color = Color(0.9, 0.9, 0.9)
	mat_white.roughness = 0.4

	# 8. Cream Wall (Chợ Bến Thành)
	var mat_cream = StandardMaterial3D.new()
	mat_cream.albedo_color = Color(0.95, 0.9, 0.72)
	mat_cream.roughness = 0.85
	
	# 9. Mái ngói terracotta (Chợ Bến Thành)
	var mat_terracotta = StandardMaterial3D.new()
	mat_terracotta.albedo_color = Color(0.78, 0.28, 0.16)
	mat_terracotta.roughness = 0.9

	# 10. Thân gỗ (Cây cối)
	var mat_trunk = StandardMaterial3D.new()
	mat_trunk.albedo_color = Color(0.38, 0.24, 0.15)
	mat_trunk.roughness = 0.9
	
	# 11. Lá cây xanh lục đậm
	var mat_leaves_dark = StandardMaterial3D.new()
	mat_leaves_dark.albedo_color = Color(0.12, 0.32, 0.14)
	mat_leaves_dark.roughness = 0.95
	
	# 12. Lá cây xanh lá tự nhiên
	var mat_leaves_bright = StandardMaterial3D.new()
	mat_leaves_bright.albedo_color = Color(0.18, 0.44, 0.20)
	mat_leaves_bright.roughness = 0.9
	
	# 13. Lá cây xanh ngả vàng
	var mat_leaves_yellow = StandardMaterial3D.new()
	mat_leaves_yellow.albedo_color = Color(0.28, 0.46, 0.12)
	mat_leaves_yellow.roughness = 0.9

	# 14. Nước sông Sài Gòn
	var mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.1, 0.3, 0.5, 0.85)
	mat_water.roughness = 0.1
	mat_water.metallic = 0.2
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# 15. Dây văng cầu
	var mat_cable = StandardMaterial3D.new()
	mat_cable.albedo_color = Color(0.8, 0.8, 0.8)
	mat_cable.metallic = 0.5
	mat_cable.roughness = 0.3
	
	# 16. Tháp cầu
	var mat_bridge_tower = StandardMaterial3D.new()
	mat_bridge_tower.albedo_color = Color(0.9, 0.9, 0.9)
	mat_bridge_tower.roughness = 0.5
	
	# 17. Kính Marina Tower
	var mat_luxury_glass = StandardMaterial3D.new()
	mat_luxury_glass.albedo_color = Color(0.4, 0.8, 0.9, 0.6)
	mat_luxury_glass.roughness = 0.05
	mat_luxury_glass.metallic = 0.8
	mat_luxury_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# --- Generate Grass Ground Planes ---
	mat_grass = StandardMaterial3D.new()
	mat_grass.albedo_color = Color(0.18, 0.42, 0.20) # Deep natural grass green
	mat_grass.roughness = 0.95

	# 1. Solid Grass (Underground section: Z = -1000 to Z = 2060)
	var ground_solid_start = MeshInstance3D.new()
	ground_solid_start.name = "GrassGround_Solid_Start"
	var mesh_solid_start = PlaneMesh.new()
	mesh_solid_start.size = Vector2(3000.0, 3060.0)
	ground_solid_start.mesh = mesh_solid_start
	ground_solid_start.material_override = mat_grass
	ground_solid_start.position = Vector3(0.0, 0.0, 530.0)
	main_scene.add_child(ground_solid_start)

	# 2. Left Grass (Transition section: Z = 2060 to Z = 2500)
	var ground_l = MeshInstance3D.new()
	ground_l.name = "GrassGround_Left"
	var mesh_l = PlaneMesh.new()
	mesh_l.size = Vector2(1493.0, 440.0)
	ground_l.mesh = mesh_l
	ground_l.material_override = mat_grass
	ground_l.position = Vector3(-753.5, 0.0, 2280.0)
	main_scene.add_child(ground_l)

	# 3. Right Grass (Transition section: Z = 2060 to Z = 2500)
	var ground_r = MeshInstance3D.new()
	ground_r.name = "GrassGround_Right"
	var mesh_r = PlaneMesh.new()
	mesh_r.size = Vector2(1493.0, 440.0)
	ground_r.mesh = mesh_r
	ground_r.material_override = mat_grass
	ground_r.position = Vector3(753.5, 0.0, 2280.0)
	main_scene.add_child(ground_r)

	# 4. Solid Grass (Elevated section: Z = 2500 to Z = 7500)
	var ground_solid = MeshInstance3D.new()
	ground_solid.name = "GrassGround_Solid"
	var mesh_solid = PlaneMesh.new()
	mesh_solid.size = Vector2(3000.0, 5000.0)
	ground_solid.mesh = mesh_solid
	ground_solid.material_override = mat_grass
	ground_solid.position = Vector3(0.0, 0.0, 5000.0)
	main_scene.add_child(ground_solid)
	
	# --- Scenery Roots ---
	var pillars_root = Node3D.new()
	pillars_root.name = "ProceduralPillars"
	main_scene.add_child(pillars_root)
	
	city_root = Node3D.new()
	city_root.name = "ProceduralCity"
	main_scene.add_child(city_root)
	
	trees_root = Node3D.new()
	trees_root.name = "ProceduralTrees"
	main_scene.add_child(trees_root)
	
	tracks_root = Node3D.new()
	tracks_root.name = "ProceduralTracks"
	main_scene.add_child(tracks_root)
	
	# Initialize random generator
	randomize()
	_init_tree_meshes()
	
	# Fill background city behind Ben Thanh (Z < 0) so the camera doesn't see a void
	for bg_z in range(-800, 0, 40):
		var bg_pos = Vector3(0, 0, bg_z)
		_spawn_city_buildings(city_root, bg_pos, bg_z, 0.0, 0.0, mat_concrete, mat_blue_glass, mat_dark_steel, mat_white, mat_emission)
		# Also spawn some trees there
		_spawn_tree(trees_root, bg_pos, bg_z, 0.0, 0.0, mat_trunk, mat_leaves_dark, mat_leaves_bright, mat_leaves_yellow)

	
	# --- Main Scenery Loop ---
	var offset = 0.0
	while offset < total_length:
		var pos = curve.sample_baked(offset)
		var global_pos = path1.to_global(pos)
		
		# Compute track tangent angle and center
		var next_offset = min(offset + 2.0, total_length)
		var next_pos = curve.sample_baked(next_offset)
		var next_global = path1.to_global(next_pos)
		var dir = (next_global - global_pos).normalized()
		var angle_y = atan2(dir.x, dir.z)
		var center_x = global_pos.x - 3.5
		
		# 1. Spawn T-Pillars on elevated sections (Y >= 5)
		if global_pos.y >= 5.0:
			_spawn_t_pillar(pillars_root, global_pos, center_x, angle_y, mat_concrete)
			
			# Spawn perpendicular road halfway between pillars (every 200m)
			if int(offset) % 200 == 0:
				var road_pos = global_pos + dir * 20.0
				var road_center_x = road_pos.x - 3.5
				_spawn_perpendicular_road(city_root, road_pos, road_center_x, angle_y, mat_asphalt, mat_white, mat_emission)
				
			# Spawn parallel highway segment every 40m
			_spawn_parallel_highway(city_root, global_pos, offset, center_x, angle_y, mat_concrete, mat_asphalt, mat_dark_steel)
		
		# 2. Spawn Chợ Bến Thành ngay trên ga Bến Thành (Z = 0)
		if offset == 0.0:
			_spawn_ben_thanh_market(city_root, center_x, angle_y, mat_cream, mat_terracotta, mat_concrete, mat_dark_steel, mat_white)

		# 3. Spawn City elements (skyscrapers) everywhere from Z = 0 to Z = 6500 (covers above tunnel & elevated viaduct)
		if global_pos.z >= 0.0 and global_pos.z <= 6500.0:
			if global_pos.z < 1400.0 or global_pos.z > 1950.0:
				_spawn_city_buildings(city_root, global_pos, offset, center_x, angle_y, mat_concrete, mat_blue_glass, mat_dark_steel, mat_white, mat_emission)
		
		# 3.5 Spawn Ba Son Area
		if int(offset) == 1520:
			_spawn_ba_son_area(city_root, center_x, angle_y, mat_concrete, mat_dark_steel, mat_water, mat_bridge_tower, mat_cable, mat_luxury_glass, mat_asphalt)
			
		# 4. Spawn Safety Barriers for the trench/slit (Z between 2000 and 2500, every 10 meters)
		if global_pos.z >= 2000.0 and global_pos.z <= 2500.0 and int(offset) % 10 == 0:
			_spawn_safety_barriers(city_root, global_pos, center_x, angle_y, mat_concrete)
		
		# 5. Spawn Transition Canopy (Z between 2060 and 2500, every 10 meters)
		if global_pos.z >= 2060.0 and global_pos.z <= 2500.0 and int(offset) % 10 == 0:
			_spawn_transition_canopy(city_root, global_pos, center_x, angle_y, mat_concrete, mat_canopy_glass, mat_dark_steel)
			
		# 6. Spawn Tunnel Lights (Y < -5)
		if global_pos.y < -5.0:
			_spawn_tunnel_lights(pillars_root, global_pos, offset, angle_y, center_x, mat_emission)
			
		# 7. Spawn cây xanh dọc đường sắt đô thị (Đô thị xanh)
		if global_pos.z >= 0.0 and global_pos.z <= 6500.0:
			if global_pos.z < 1400.0 or global_pos.z > 1950.0:
				_spawn_tree(trees_root, global_pos, offset, center_x, angle_y, mat_trunk, mat_leaves_dark, mat_leaves_bright, mat_leaves_yellow)
			
		offset += 40.0

	_generate_track_sleepers(path1, mat_trunk)
	var path2 = main_scene.get_node_or_null("Path3D_2")
	if path2:
		_generate_track_sleepers(path2, mat_trunk)
		
	_flush_tree_multimeshes()
	_set_visibility_range(city_root, 600.0)
	_set_visibility_range(pillars_root, 600.0)
	_set_visibility_range(tracks_root, 600.0)

func _spawn_t_pillar(root: Node3D, pos: Vector3, center_x: float, angle_y: float, mat: Material):
	var pillar_node = Node3D.new()
	pillar_node.name = "TPillar_" + str(int(pos.z))
	root.add_child(pillar_node)
	
	# Rotate and position the pillar combiner node itself
	pillar_node.position = Vector3(center_x, 0.0, pos.z)
	pillar_node.rotation.y = angle_y
	
	# Vertical Column (local to combiner)
	var col = MeshInstance3D.new()
	var col_m = CylinderMesh.new()
	col_m.bottom_radius = 1.0
	col_m.top_radius = 1.0
	col_m.height = pos.y
	col.mesh = col_m
	col.material_override = mat
	col.position = Vector3(0.0, pos.y / 2.0, 0.0)
	pillar_node.add_child(col)
	
	# Horizontal Cross-Beam (local to combiner)
	var beam = MeshInstance3D.new()
	var beam_m = BoxMesh.new()
	beam_m.size = Vector3(11.0, 1.2, 2.5)
	beam.mesh = beam_m
	beam.material_override = mat
	beam.position = Vector3(0.0, pos.y - 0.6, 0.0)
	pillar_node.add_child(beam)

func _spawn_crossover_track(root: Node3D, pos: Vector3, center_x: float, angle_y: float, mat_steel: Material, mat_concrete: Material, mat_emission: Material):
	var crossover = Node3D.new()
	crossover.name = "CrossoverTrack_" + str(int(pos.z))
	root.add_child(crossover)
	
	crossover.position = Vector3(center_x, pos.y, pos.z)
	crossover.rotation.y = angle_y
	
	# Attempt to get original track materials from Main.tscn
	var trackbed_mat = mat_concrete
	var rail_mat = mat_steel
	if main_scene:
		var path1 = main_scene.get_node_or_null("Path3D_1")
		if path1:
			var tb = path1.get_node_or_null("CSGPolygon3D")
			if tb and tb.material: trackbed_mat = tb.material
			var rl = path1.get_node_or_null("RailLeft")
			if rl and rl.material: rail_mat = rl.material
			
	var length = 50.0
	var z_offset = length / 2.0
	
	# Path 1: Left to Right (-3.5 to 3.5)
	var curve1 = Curve3D.new()
	curve1.add_point(Vector3(-3.5, 0, -z_offset), Vector3(0, 0, -15), Vector3(0, 0, 15))
	curve1.add_point(Vector3(3.5, 0, z_offset), Vector3(0, 0, -15), Vector3(0, 0, 15))
	
	# Path 2: Right to Left (3.5 to -3.5)
	var curve2 = Curve3D.new()
	curve2.add_point(Vector3(3.5, 0, -z_offset), Vector3(0, 0, -15), Vector3(0, 0, 15))
	curve2.add_point(Vector3(-3.5, 0, z_offset), Vector3(0, 0, -15), Vector3(0, 0, 15))
	
	var paths = [curve1, curve2]
	
	# Unified concrete base for crossover
	var base = CSGBox3D.new()
	base.size = Vector3(10.0, 0.5, length)
	base.position = Vector3(0, 0.25, 0)
	base.material = trackbed_mat
	crossover.add_child(base)
	
	for i in range(paths.size()):
		var path = Path3D.new()
		path.curve = paths[i]
		crossover.add_child(path)
		
		# (Removed individual curved trackbeds to prevent Z-fighting and messy textures)
		
		# Left Rail
		var rail_l = CSGPolygon3D.new()
		rail_l.polygon = PackedVector2Array([Vector2(-0.75, 0.5), Vector2(-0.65, 0.5), Vector2(-0.65, 0.6), Vector2(-0.75, 0.6)])
		rail_l.mode = CSGPolygon3D.MODE_PATH
		rail_l.path_node = NodePath("..")
		rail_l.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
		rail_l.path_interval = 1.0
		rail_l.path_rotation = 2
		rail_l.path_local = true
		rail_l.path_continuous_u = true
		rail_l.material = rail_mat
		path.add_child(rail_l)
		
		# Right Rail
		var rail_r = CSGPolygon3D.new()
		rail_r.polygon = PackedVector2Array([Vector2(0.65, 0.5), Vector2(0.75, 0.5), Vector2(0.75, 0.6), Vector2(0.65, 0.6)])
		rail_r.mode = CSGPolygon3D.MODE_PATH
		rail_r.path_node = NodePath("..")
		rail_r.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
		rail_r.path_interval = 1.0
		rail_r.path_rotation = 2
		rail_r.path_local = true
		rail_r.path_continuous_u = true
		rail_r.material = rail_mat
		path.add_child(rail_r)
			
	# Add Switch Boxes and Glowing Signal Lights
	for z_pos in [-z_offset, z_offset]:
		for x_pos in [-4.5, 4.5]:
			# Signal Light
			var switch_light = OmniLight3D.new()
			switch_light.position = Vector3(x_pos, 1.0, z_pos)
			switch_light.light_color = Color(1.0, 0.8, 0.2)
			switch_light.light_energy = 3.0
			switch_light.omni_range = 10.0
			crossover.add_child(switch_light)
			
			# Switch Motor Box
			var box = CSGBox3D.new()
			box.size = Vector3(0.6, 0.4, 0.8)
			box.position = Vector3(x_pos, 0.2, z_pos)
			box.material = mat_concrete
			crossover.add_child(box)
			
			# Signal Lamp indicator
			var lamp = CSGBox3D.new()
			lamp.size = Vector3(0.2, 0.2, 0.2)
			lamp.position = Vector3(x_pos, 0.5, z_pos)
			lamp.material = mat_emission
			crossover.add_child(lamp)


func _spawn_transition_canopy(root: Node3D, pos: Vector3, center_x: float, angle_y: float, mat_concrete: Material, mat_glass: Material, mat_frame: Material):
	var canopy = Node3D.new()
	canopy.name = "Canopy_" + str(int(pos.z))
	root.add_child(canopy)
	
	# Set position and rotation of the canopy root
	canopy.position = Vector3(center_x, 0.0, pos.z)
	canopy.rotation.y = angle_y
	
	# Left Concrete Wall (sits on ground Y=0, height=6m, local X=-6.5)
	var wall_l = MeshInstance3D.new()
	var wall_mesh = BoxMesh.new()
	wall_mesh.size = Vector3(0.4, 6.0, 10.2)
	wall_l.mesh = wall_mesh
	wall_l.material_override = mat_concrete
	wall_l.position = Vector3(-6.5, 3.0, 0.0)
	canopy.add_child(wall_l)
	
	# Right Concrete Wall
	var wall_r = MeshInstance3D.new()
	wall_r.mesh = wall_mesh
	wall_r.material_override = mat_concrete
	wall_r.position = Vector3(6.5, 3.0, 0.0)
	canopy.add_child(wall_r)
	
	# Arched Roof Panes (Glass + Frame)
	# Left Sloped Pane
	var pane_l = MeshInstance3D.new()
	var pane_mesh_side = BoxMesh.new()
	pane_mesh_side.size = Vector3(3.2, 0.1, 10.2)
	pane_l.mesh = pane_mesh_side
	pane_l.material_override = mat_glass
	pane_l.position = Vector3(-5.25, 7.0, 0.0)
	pane_l.rotation.z = deg_to_rad(38)
	canopy.add_child(pane_l)
	
	# Right Sloped Pane
	var pane_r = MeshInstance3D.new()
	pane_r.mesh = pane_mesh_side
	pane_r.material_override = mat_glass
	pane_r.position = Vector3(5.25, 7.0, 0.0)
	pane_r.rotation.z = deg_to_rad(-38)
	canopy.add_child(pane_r)
	
	# Top Flat Pane
	var pane_t = MeshInstance3D.new()
	var pane_mesh_top = BoxMesh.new()
	pane_mesh_top.size = Vector3(8.5, 0.1, 10.2)
	pane_t.mesh = pane_mesh_top
	pane_t.material_override = mat_glass
	pane_t.position = Vector3(0.0, 8.0, 0.0)
	canopy.add_child(pane_t)
	
	# Decorative Metal Frame Ribs (front and back of the segment)
	for z_offset in [-5.0, 5.0]:
		var rib = Node3D.new()
		canopy.add_child(rib)
		rib.position.z = z_offset
		
		# Left Wall Beam
		var beam_l = MeshInstance3D.new()
		var beam_mesh = BoxMesh.new()
		beam_mesh.size = Vector3(0.2, 6.0, 0.2)
		beam_l.mesh = beam_mesh
		beam_l.material_override = mat_frame
		beam_l.position = Vector3(-6.5, 3.0, 0.0)
		rib.add_child(beam_l)
		
		# Right Wall Beam
		var beam_r = MeshInstance3D.new()
		beam_r.mesh = beam_mesh
		beam_r.material_override = mat_frame
		beam_r.position = Vector3(6.5, 3.0, 0.0)
		rib.add_child(beam_r)
		
		# Top cross rib
		var beam_t = MeshInstance3D.new()
		var top_rib_mesh = BoxMesh.new()
		top_rib_mesh.size = Vector3(8.5, 0.2, 0.2)
		beam_t.mesh = top_rib_mesh
		beam_t.material_override = mat_frame
		beam_t.position = Vector3(0.0, 8.0, 0.0)
		rib.add_child(beam_t)

func _spawn_ba_son_area(root: Node3D, center_x: float, angle_y: float, mat_concrete: Material, mat_dark_steel: Material, mat_water: Material, mat_bridge_tower: Material, mat_cable: Material, mat_luxury_glass: Material, mat_asphalt: Material):
	# 1. Saigon River
	# Center of the river roughly at Z = 1750
	var river = MeshInstance3D.new()
	var r_mesh = PlaneMesh.new()
	r_mesh.size = Vector2(4000.0, 400.0) # Length 4000, Width 400
	river.mesh = r_mesh
	river.material_override = mat_water
	river.position = Vector3(center_x, 0.5, 1750.0)
	# River flows diagonally (its X axis is the length, so rotation +45 means length is at +135 deg)
	river.rotation.y = angle_y + deg_to_rad(45.0)
	root.add_child(river)
	
	# 2. Ba Son Bridge
	# Perpendicular to the river (+45 degrees relative to track)
	var bridge = Node3D.new()
	bridge.name = "BaSonBridge"
	bridge.position = Vector3(center_x, 0.0, 1750.0)
	bridge.rotation.y = angle_y + deg_to_rad(45.0)
	root.add_child(bridge)
	
	# Bridge Deck
	var deck = CSGBox3D.new()
	deck.size = Vector3(32.0, 2.0, 600.0)
	deck.position = Vector3(0.0, 20.0, 0.0)
	deck.material = mat_asphalt
	bridge.add_child(deck)
	
	# Bridge Edge barriers
	for dx in [-16.0, 16.0]:
		var barrier = CSGBox3D.new()
		barrier.size = Vector3(0.5, 3.0, 600.0)
		barrier.position = Vector3(dx, 21.5, 0.0)
		barrier.material = mat_concrete
		bridge.add_child(barrier)
	
	# Pylon (A-shaped sweeping tower)
	var pylon = CSGBox3D.new()
	pylon.size = Vector3(8.0, 120.0, 12.0)
	pylon.position = Vector3(0.0, 60.0, -150.0)
	pylon.rotation_degrees.x = 15.0 # Leaning back
	pylon.material = mat_bridge_tower
	bridge.add_child(pylon)
	
	# Cables
	var pylon_top_local = Vector3(0.0, 110.0, -165.0)
	for deck_z in range(-50, 250, 25):
		for deck_x in [-15.0, 15.0]:
			var cable = MeshInstance3D.new()
			bridge.add_child(cable)
			
			# Calculate global points to use look_at correctly
			var p1 = bridge.to_global(Vector3(deck_x, 21.0, deck_z))
			var p2 = bridge.to_global(pylon_top_local)
			var dist = p1.distance_to(p2)
			
			var c_mesh = CylinderMesh.new()
			c_mesh.top_radius = 0.25
			c_mesh.bottom_radius = 0.25
			c_mesh.height = dist
			cable.mesh = c_mesh
			cable.material_override = mat_cable
			
			cable.global_position = (p1 + p2) / 2.0
			cable.look_at(p2, Vector3.UP)
			cable.rotation_degrees.x -= 90.0
			
	# 3. Marina Towers (Vinhomes Golden River)
	# Adjusted coords to ensure they are on the bank, not the river itself (X + Z < 1460)
	var tower_coords = [
		Vector3(-80, 0, 1420),
		Vector3(-130, 0, 1480),
		Vector3(120, 0, 1200),
		Vector3(160, 0, 1220)
	]
	
	for i in range(tower_coords.size()):
		var t_pos = tower_coords[i]
		var tower = Node3D.new()
		tower.name = "MarinaTower_" + str(i)
		tower.position = Vector3(center_x, 0.0, 1500.0) + Vector3(t_pos.x, 0.0, t_pos.z - 1500.0).rotated(Vector3.UP, angle_y)
		tower.rotation.y = angle_y
		root.add_child(tower)
		
		var t_height = 130.0 + (i * 20.0)
		var body = CSGBox3D.new()
		body.size = Vector3(30.0, t_height, 30.0)
		body.position = Vector3(0, t_height / 2.0, 0)
		body.material = mat_luxury_glass
		tower.add_child(body)
		
		# White frames on sides
		for fx in [-15.5, 15.5]:
			var frame = CSGBox3D.new()
			frame.size = Vector3(1.0, t_height + 2.0, 31.0)
			frame.position = Vector3(fx, t_height / 2.0, 0)
			frame.material = mat_concrete
			tower.add_child(frame)
			
	# 4. The Sun Tower (Signature Block)
	var sun_tower = Node3D.new()
	sun_tower.name = "SunTower"
	# Moved back to Z=1400 (from 1480) to avoid river
	sun_tower.position = Vector3(center_x, 0.0, 1520.0) + Vector3(80.0, 0.0, -120.0).rotated(Vector3.UP, angle_y)
	sun_tower.rotation.y = angle_y
	root.add_child(sun_tower)
	
	var sun_body = CSGBox3D.new()
	sun_body.size = Vector3(45.0, 160.0, 45.0)
	sun_body.position = Vector3(0, 80.0, 0)
	sun_body.material = mat_luxury_glass
	sun_tower.add_child(sun_body)
	
	var sun_cap = CSGBox3D.new()
	sun_cap.size = Vector3(46.0, 10.0, 46.0)
	sun_cap.position = Vector3(0, 165.0, 0)
	sun_cap.material = mat_dark_steel
	sun_tower.add_child(sun_cap)


func _spawn_safety_barriers(root: Node3D, pos: Vector3, center_x: float, angle_y: float, mat_concrete: Material):
	var barrier_node = Node3D.new()
	barrier_node.name = "SafetyBarrier_" + str(int(pos.z))
	root.add_child(barrier_node)
	
	barrier_node.position = Vector3(center_x, 0.0, pos.z)
	barrier_node.rotation.y = angle_y
	
	# Left concrete barrier (local X = -7.0)
	var barrier_l = MeshInstance3D.new()
	var barrier_mesh = BoxMesh.new()
	barrier_mesh.size = Vector3(0.3, 1.0, 10.2)
	barrier_l.mesh = barrier_mesh
	barrier_l.material_override = mat_concrete
	barrier_l.position = Vector3(-7.0, 0.5, 0.0)
	barrier_node.add_child(barrier_l)
	
	# Right concrete barrier (local X = 7.0)
	var barrier_r = MeshInstance3D.new()
	barrier_r.mesh = barrier_mesh
	barrier_r.material_override = mat_concrete
	barrier_r.position = Vector3(7.0, 0.5, 0.0)
	barrier_node.add_child(barrier_r)


func _spawn_city_buildings(root: Node3D, pos: Vector3, seed_val: float, center_x: float, angle_y: float, mat_concrete: Material, mat_glass: Material, mat_steel: Material, mat_white: Material, mat_emission: Material):
	# Use a deterministic pseudo-random seed based on position
	var l_rng = RandomNumberGenerator.new()
	l_rng.seed = int(seed_val * 777)
	
	# 75% chance to spawn building on left/right
	for side in [-1, 1]:
		if l_rng.randf() > 0.35:
			var b_style = l_rng.randi_range(0, 3)
			var b_height = l_rng.randf_range(30.0, 95.0)
			var b_width = l_rng.randf_range(16.0, 26.0)
			var b_depth = l_rng.randf_range(16.0, 26.0)
			
			# Giữ các tòa nhà cách đường ray một khoảng an toàn
			var min_x = 38.0
			if pos.z < 2200.0:
				if pos.z < 200.0:
					min_x = 40.0 # Tạo quảng trường rộng xung quanh Chợ Bến Thành
				else:
					min_x = 14.0 # Giữ khoảng cách ngoài rãnh cỏ 14m
				
			var dist_x = l_rng.randf_range(min_x, 110.0)
			var local_pos = Vector3(side * dist_x, b_height / 2.0, l_rng.randf_range(-15.0, 15.0))
			
			var building = Node3D.new()
			building.name = "Building_" + str(int(local_pos.x)) + "_" + str(int(pos.z))
			
			# Set position relative to center_x, and rotate to follow track angle
			building.position = Vector3(center_x, 0.0, pos.z)
			building.rotation.y = angle_y
			
			# Tránh xây nhà trên mặt sông Sài Gòn (Z = 1750, chéo 45 độ)
			var global_b_pos = building.position + local_pos.rotated(Vector3.UP, angle_y)
			if abs((global_b_pos.x - center_x) + (global_b_pos.z - 1750.0)) < 400.0:
				building.queue_free()
				continue
				
			root.add_child(building)
			
			# Now add children relative to building origin (local_pos)
			match b_style:
				0: # Glass Office Tower
					# Main glass block
					var body = MeshInstance3D.new()
					var mesh = BoxMesh.new()
					mesh.size = Vector3(b_width, b_height, b_depth)
					body.mesh = mesh
					body.material_override = mat_glass
					body.position = local_pos
					building.add_child(body)
					
					# Concrete side frames
					var frame_l = MeshInstance3D.new()
					var f_mesh = BoxMesh.new()
					f_mesh.size = Vector3(1.0, b_height + 2.0, b_depth + 0.2)
					frame_l.mesh = f_mesh
					frame_l.material_override = mat_white
					frame_l.position = local_pos + Vector3(-b_width/2.0, 1.0, 0.0)
					building.add_child(frame_l)
					
					var frame_r = MeshInstance3D.new()
					frame_r.mesh = f_mesh
					frame_r.material_override = mat_white
					frame_r.position = local_pos + Vector3(b_width/2.0, 1.0, 0.0)
					building.add_child(frame_r)
					
				1: # Stepped Tower
					# 3 nested blocks going smaller as they go up
					var tier_h = b_height / 3.0
					for tier in range(3):
						var scale_f = 1.0 - (tier * 0.25)
						var t_w = b_width * scale_f
						var t_d = b_depth * scale_f
						
						var block = MeshInstance3D.new()
						var mesh = BoxMesh.new()
						mesh.size = Vector3(t_w, tier_h, t_d)
						block.mesh = mesh
						block.material_override = mat_concrete
						block.position = local_pos + Vector3(0.0, (tier * tier_h) - (b_height / 2.0) + (tier_h / 2.0), 0.0)
						building.add_child(block)
						
						# Add glowing yellow window stripes on each tier
						var windows = MeshInstance3D.new()
						var w_mesh = BoxMesh.new()
						w_mesh.size = Vector3(t_w + 0.1, tier_h - 2.0, t_d + 0.1)
						windows.mesh = w_mesh
						windows.material_override = mat_emission
						windows.position = block.position
						building.add_child(windows)
						
					# Spire on top
					var spire = MeshInstance3D.new()
					var s_mesh = CylinderMesh.new()
					s_mesh.top_radius = 0.05
					s_mesh.bottom_radius = 0.2
					s_mesh.height = 8.0
					spire.mesh = s_mesh
					spire.material_override = mat_steel
					spire.position = local_pos + Vector3(0.0, (b_height / 2.0) + 4.0, 0.0)
					building.add_child(spire)
					
				2: # Residential High-rise
					# Main beige block
					var body = MeshInstance3D.new()
					var mesh = BoxMesh.new()
					mesh.size = Vector3(b_width, b_height, b_depth)
					body.mesh = mesh
					body.material_override = mat_white
					body.position = local_pos
					building.add_child(body)
					
					# Horizontal dark window stripes
					var num_floors = int(b_height / 4.0)
					for floor_idx in range(num_floors):
						var stripe = MeshInstance3D.new()
						var s_mesh = BoxMesh.new()
						s_mesh.size = Vector3(b_width + 0.1, 1.2, b_depth + 0.1)
						stripe.mesh = s_mesh
						stripe.material_override = mat_steel
						stripe.position = local_pos + Vector3(0.0, - (b_height / 2.0) + (floor_idx * 4.0) + 2.0, 0.0)
						building.add_child(stripe)
						
				3: # Corporate Block
					# Wide angular building
					var body = MeshInstance3D.new()
					var mesh = BoxMesh.new()
					mesh.size = Vector3(b_width * 1.5, b_height, b_depth)
					body.mesh = mesh
					body.material_override = mat_steel
					body.position = local_pos
					building.add_child(body)
					
					# Vertical columns in front
					for col_idx in range(5):
						var col = MeshInstance3D.new()
						var c_mesh = BoxMesh.new()
						c_mesh.size = Vector3(0.6, b_height, 0.4)
						col.mesh = c_mesh
						col.material_override = mat_white
						col.position = local_pos + Vector3( - (b_width * 0.7) + (col_idx * (b_width * 0.35)), 0.0, (b_depth / 2.0) + 0.1 )
						building.add_child(col)


func _spawn_perpendicular_road(root: Node3D, pos: Vector3, center_x: float, angle_y: float, mat_road: Material, mat_line: Material, mat_light: Material):
	var road = Node3D.new()
	road.name = "PerpRoad_" + str(int(pos.z))
	root.add_child(road)
	
	# Set position and rotation of the road root
	road.position = Vector3(center_x, 0.0, pos.z)
	road.rotation.y = angle_y
	
	# Asphalt road bed (extends 200m left and right locally)
	var bed = MeshInstance3D.new()
	var bed_mesh = BoxMesh.new()
	bed_mesh.size = Vector3(500.0, 0.1, 15.0)
	bed.mesh = bed_mesh
	bed.material_override = mat_road
	bed.position = Vector3(0.0, 0.05, 0.0)
	road.add_child(bed)
	
	# Dashed lane markings
	for x_offset in range(-240, 240, 20):
		var dash = MeshInstance3D.new()
		var dash_mesh = BoxMesh.new()
		dash_mesh.size = Vector3(4.0, 0.12, 0.15)
		dash.mesh = dash_mesh
		dash.material_override = mat_line
		dash.position = Vector3(x_offset, 0.06, 0.0)
		road.add_child(dash)
		
	# Streetlights on poles along the road
	for side in [-1, 1]:
		for streetlight_x in [-80, -30, 30, 80]:
			var pole = Node3D.new()
			road.add_child(pole)
			pole.position = Vector3(streetlight_x, 0.0, side * 7.0)
			
			# Pole vertical
			var vert = MeshInstance3D.new()
			var pole_mesh = CylinderMesh.new()
			pole_mesh.top_radius = 0.1
			pole_mesh.bottom_radius = 0.1
			pole_mesh.height = 7.0
			vert.mesh = pole_mesh
			vert.material_override = mat_line
			vert.position.y = 3.5
			pole.add_child(vert)
			
			# Light head
			var head = MeshInstance3D.new()
			var head_mesh = BoxMesh.new()
			head_mesh.size = Vector3(1.2, 0.2, 0.4)
			head.mesh = head_mesh
			head.material_override = mat_light
			head.position = Vector3(0.0, 7.0, -side * 0.5)
			pole.add_child(head)


func _spawn_parallel_highway(root: Node3D, pos: Vector3, offset: float, center_x: float, angle_y: float, mat_concrete: Material, mat_road: Material, _mat_steel: Material):
	var segment = Node3D.new()
	segment.name = "Highway_" + str(int(pos.z))
	root.add_child(segment)
	
	# Align highway segment to track curve center and rotation
	segment.position = Vector3(center_x, 6.0, pos.z)
	segment.rotation.y = angle_y
	
	# Asphalt highway deck (40m long segment, offset by X = -45.0 locally)
	var deck = MeshInstance3D.new()
	var deck_mesh = BoxMesh.new()
	deck_mesh.size = Vector3(8.0, 0.4, 40.2)
	deck.mesh = deck_mesh
	deck.material_override = mat_road
	deck.position = Vector3(-45.0, 0.0, 0.0)
	segment.add_child(deck)
	
	# Side concrete barriers
	var barrier_l = MeshInstance3D.new()
	var bar_mesh = BoxMesh.new()
	bar_mesh.size = Vector3(0.3, 1.0, 40.2)
	barrier_l.mesh = bar_mesh
	barrier_l.material_override = mat_concrete
	barrier_l.position = Vector3(-48.85, 0.5, 0.0)
	segment.add_child(barrier_l)
	
	var barrier_r = MeshInstance3D.new()
	barrier_r.mesh = bar_mesh
	barrier_r.material_override = mat_concrete
	barrier_r.position = Vector3(-41.15, 0.5, 0.0)
	segment.add_child(barrier_r)
	
	# Support Pillars (spawn every 80m)
	if int(offset) % 80 == 0:
		var pillar = MeshInstance3D.new()
		var p_mesh = CylinderMesh.new()
		p_mesh.top_radius = 0.6
		p_mesh.bottom_radius = 0.6
		p_mesh.height = 6.0
		pillar.mesh = p_mesh
		pillar.material_override = mat_concrete
		pillar.position = Vector3(-45.0, -3.0, 0.0)
		segment.add_child(pillar)


func _spawn_tunnel_lights(root: Node3D, pos: Vector3, offset: float, angle_y: float, center_x: float, mat_emission: Material):
	# Dimmest, sparse track lights
	# Tunnels are mostly dark except around the track
	
	# Only spawn every 20 meters to illuminate the tunnel well
	if int(round(offset)) % 20 != 0:
		return
		
	var tunnel_node = Node3D.new()
	tunnel_node.name = "TunnelLight_" + str(int(offset))
	tunnel_node.position = Vector3(center_x, pos.y, pos.z)
	tunnel_node.rotation.y = angle_y
	
	root.add_child(tunnel_node)
	
	# Left wall light fixture
	var fixture_l = CSGBox3D.new()
	fixture_l.size = Vector3(0.2, 0.4, 2.0)
	fixture_l.position = Vector3(-9.0, 2.0, 0.0)
	fixture_l.material = mat_emission
	tunnel_node.add_child(fixture_l)
	
	var light_l = OmniLight3D.new()
	light_l.position = Vector3(-8.8, 2.0, 0.0)
	light_l.omni_range = 30.0
	light_l.light_color = Color(1.0, 0.85, 0.6) # Warm incandescent glow
	light_l.light_energy = 1.5
	# Tránh rò rỉ ánh sáng lên mặt nước bằng cách bật shadow trong vùng sông Sài Gòn
	light_l.shadow_enabled = abs(tunnel_node.position.z - 1750.0) < 400.0
	tunnel_node.add_child(light_l)
	
	# Right wall light fixture
	var fixture_r = CSGBox3D.new()
	fixture_r.size = Vector3(0.2, 0.4, 2.0)
	fixture_r.position = Vector3(9.0, 2.0, 0.0)
	fixture_r.material = mat_emission
	tunnel_node.add_child(fixture_r)
	
	var light_r = OmniLight3D.new()
	light_r.position = Vector3(8.8, 2.0, 0.0)
	light_r.omni_range = 30.0
	light_r.light_color = Color(1.0, 0.85, 0.6)
	light_r.light_energy = 1.5
	# Tránh rò rỉ ánh sáng lên mặt nước bằng cách bật shadow trong vùng sông Sài Gòn
	light_r.shadow_enabled = abs(tunnel_node.position.z - 1750.0) < 400.0
	tunnel_node.add_child(light_r)


func _spawn_ben_thanh_market(root: Node3D, center_x: float, angle_y: float, mat_cream: Material, mat_roof: Material, mat_concrete: Material, mat_steel: Material, mat_white: Material):
	var market_combiner = Node3D.new()
	market_combiner.name = "BenThanhMarket"
	root.add_child(market_combiner)
	
	# Đặt vị trí trên mặt đất (Y=0) ngay trên ga ngầm Bến Thành
	market_combiner.position = Vector3(center_x, 0.0, 0.0)
	market_combiner.rotation.y = angle_y
	
	# 1. Thân chợ chính (Nhà lồng)
	var main_body = CSGBox3D.new()
	main_body.size = Vector3(24.0, 5.0, 36.0)
	main_body.position = Vector3(0.0, 2.5, 0.0)
	main_body.material = mat_cream
	market_combiner.add_child(main_body)
	
	# 2. Mái nhà lồng chính (Dùng CSGPolygon3D để làm mái tam giác chạy dọc trục Z)
	var main_roof = CSGPolygon3D.new()
	main_roof.polygon = PackedVector2Array([
		Vector2(-12.1, 0.0),
		Vector2(0.0, 4.0),
		Vector2(12.1, 0.0)
	])
	main_roof.depth = 36.2
	main_roof.position = Vector3(0.0, 5.0, 18.1)
	main_roof.material = mat_roof
	market_combiner.add_child(main_roof)
	
	# 3. Thân dãy nhà bên trái
	var wing_l = CSGBox3D.new()
	wing_l.size = Vector3(10.0, 3.5, 28.0)
	wing_l.position = Vector3(-17.0, 1.75, -2.0)
	wing_l.material = mat_cream
	market_combiner.add_child(wing_l)
	
	# 4. Mái dãy nhà bên trái (Dùng CSGPolygon3D)
	var roof_l = CSGPolygon3D.new()
	roof_l.polygon = PackedVector2Array([
		Vector2(-5.1, 0.0),
		Vector2(0.0, 2.5),
		Vector2(5.1, 0.0)
	])
	roof_l.depth = 28.2
	roof_l.position = Vector3(-17.0, 3.5, 12.1)
	roof_l.material = mat_roof
	market_combiner.add_child(roof_l)
	
	# 5. Thân dãy nhà bên phải
	var wing_r = CSGBox3D.new()
	wing_r.size = Vector3(10.0, 3.5, 28.0)
	wing_r.position = Vector3(17.0, 1.75, -2.0)
	wing_r.material = mat_cream
	market_combiner.add_child(wing_r)
	
	# 6. Mái dãy nhà bên phải (Dùng CSGPolygon3D)
	var roof_r = CSGPolygon3D.new()
	roof_r.polygon = PackedVector2Array([
		Vector2(-5.1, 0.0),
		Vector2(0.0, 2.5),
		Vector2(5.1, 0.0)
	])
	roof_r.depth = 28.2
	roof_r.position = Vector3(17.0, 3.5, 12.1)
	roof_r.material = mat_roof
	market_combiner.add_child(roof_r)
	
	# 7. Tháp đồng hồ biểu tượng phía trước (Facing Z = -18)
	var tower = CSGBox3D.new()
	tower.size = Vector3(7.0, 16.0, 7.0)
	tower.position = Vector3(0.0, 8.0, -18.0)
	tower.material = mat_cream
	market_combiner.add_child(tower)
	
	# Bờ gờ phân tầng tháp
	var ledge = CSGBox3D.new()
	ledge.size = Vector3(8.0, 0.8, 8.0)
	ledge.position = Vector3(0.0, 14.0, -18.0)
	ledge.material = mat_concrete
	market_combiner.add_child(ledge)
	
	# Mặt đồng hồ hình tròn (Mặt trước, mặt trái, mặt phải)
	# Mặt trước
	var clock_f = CSGCylinder3D.new()
	clock_f.radius = 1.6
	clock_f.height = 0.2
	clock_f.position = Vector3(0.0, 11.5, -21.6)
	clock_f.rotation.x = deg_to_rad(90)
	clock_f.material = mat_white
	market_combiner.add_child(clock_f)
	
	# Kim đồng hồ mặt trước
	var clock_dot_f = CSGCylinder3D.new()
	clock_dot_f.radius = 0.2
	clock_dot_f.height = 0.3
	clock_dot_f.position = Vector3(0.0, 11.5, -21.7)
	clock_dot_f.rotation.x = deg_to_rad(90)
	clock_dot_f.material = mat_steel
	market_combiner.add_child(clock_dot_f)
	
	# Mặt bên trái
	var clock_l = CSGCylinder3D.new()
	clock_l.radius = 1.6
	clock_l.height = 0.2
	clock_l.position = Vector3(-3.6, 11.5, -18.0)
	clock_l.rotation.z = deg_to_rad(90)
	clock_l.material = mat_white
	market_combiner.add_child(clock_l)
	
	var clock_dot_l = CSGCylinder3D.new()
	clock_dot_l.radius = 0.2
	clock_dot_l.height = 0.3
	clock_dot_l.position = Vector3(-3.7, 11.5, -18.0)
	clock_dot_l.rotation.z = deg_to_rad(90)
	clock_dot_l.material = mat_steel
	market_combiner.add_child(clock_dot_l)
	
	# Mặt bên phải
	var clock_r = CSGCylinder3D.new()
	clock_r.radius = 1.6
	clock_r.height = 0.2
	clock_r.position = Vector3(3.6, 11.5, -18.0)
	clock_r.rotation.z = deg_to_rad(90)
	clock_r.material = mat_white
	market_combiner.add_child(clock_r)
	
	var clock_dot_r = CSGCylinder3D.new()
	clock_dot_r.radius = 0.2
	clock_dot_r.height = 0.3
	clock_dot_r.position = Vector3(3.7, 11.5, -18.0)
	clock_dot_r.rotation.z = deg_to_rad(90)
	clock_dot_r.material = mat_steel
	market_combiner.add_child(clock_dot_r)
	
	# Chóp tháp hình phân kim (Dùng CSGCylinder3D với sides=4 và cone=true)
	var spire = CSGCylinder3D.new()
	spire.radius = 3.6
	spire.height = 5.0
	spire.sides = 4
	spire.cone = true
	spire.position = Vector3(0.0, 18.5, -18.0)
	spire.rotation.y = deg_to_rad(45)
	spire.material = mat_roof
	market_combiner.add_child(spire)
	
	# Cột thu lôi / Đỉnh chóp tháp
	var tip = CSGCylinder3D.new()
	tip.radius = 0.08
	tip.height = 2.0
	tip.position = Vector3(0.0, 21.5, -18.0)
	tip.material = mat_steel
	market_combiner.add_child(tip)


func _spawn_tree(root: Node3D, pos: Vector3, seed_val: float, center_x: float, angle_y: float, mat_trunk: Material, mat_leaves_dark: Material, mat_leaves_bright: Material, mat_leaves_yellow: Material):
	var l_rng = RandomNumberGenerator.new()
	l_rng.seed = int(seed_val * 999)
	var num_trees = l_rng.randi_range(6, 12)
	
	for i in range(num_trees):
		var side = 1 if l_rng.randf() > 0.5 else -1
		var dist_x = 0.0
		var dist_z = l_rng.randf_range(-20.0, 20.0)
		
		if pos.z < 2000.0:
			if pos.z < 200.0:
				dist_x = l_rng.randf_range(15.0, 80.0)
			else:
				dist_x = l_rng.randf_range(6.0, 75.0)
		elif pos.z >= 2000.0 and pos.z < 2500.0:
			dist_x = l_rng.randf_range(8.5, 75.0)
		else:
			if l_rng.randf() > 0.6:
				dist_x = l_rng.randf_range(0.0, 3.5)
			else:
				dist_x = l_rng.randf_range(12.0, 75.0)
				
		var local_pos = Vector3(side * dist_x, 0.0, dist_z)
		var tree_pos = Vector3(center_x, 0.0, pos.z) + Vector3(local_pos.x, 0.0, local_pos.z).rotated(Vector3.UP, angle_y)
		
		if abs((tree_pos.x - center_x) + (tree_pos.z - 1750.0)) < 400.0:
			continue
			
		var tree_rot_y = angle_y + l_rng.randf_range(-PI, PI)
		var scale_factor = l_rng.randf_range(0.8, 1.4)
		var base_xform = Transform3D(Basis().rotated(Vector3.UP, tree_rot_y).scaled(Vector3.ONE * scale_factor), tree_pos)
		
		var mat_leaves = mat_leaves_bright
		var leaves_rand = l_rng.randf()
		if leaves_rand < 0.35:
			mat_leaves = mat_leaves_dark
		elif leaves_rand > 0.75:
			mat_leaves = mat_leaves_yellow
			
		var tree_type = l_rng.randi_range(0, 4)
		
		if tree_type != 4:
			_add_tree_instance("trunk", mat_trunk, base_xform * Transform3D(Basis(), Vector3(0, 0.9, 0)))
			
		match tree_type:
			0:
				_add_tree_instance("type0", mat_leaves, base_xform * Transform3D(Basis(), Vector3(0, 1.8, 0)))
			1:
				_add_tree_instance("type1", mat_leaves, base_xform * Transform3D(Basis(), Vector3(0, 2.0, 0)))
			2:
				_add_tree_instance("type2", mat_leaves, base_xform * Transform3D(Basis(), Vector3(0, 1.9, 0)))
			3:
				var leaves_l_rng = RandomNumberGenerator.new()
				leaves_l_rng.seed = int(seed_val * i * 3)
				_add_tree_instance("type3_main", mat_leaves, base_xform * Transform3D(Basis(), Vector3(0, 2.0, 0)))
				for s in range(2):
					var offset_angle = leaves_l_rng.randf_range(0.0, 2 * PI)
					var offset_dist = leaves_l_rng.randf_range(0.3, 0.6)
					var side_pos = Vector3(cos(offset_angle) * offset_dist, 2.2 + leaves_l_rng.randf_range(-0.2, 0.2), sin(offset_angle) * offset_dist)
					_add_tree_instance("type3_main", mat_leaves, base_xform * Transform3D(Basis(), side_pos))
			4:
				_add_tree_instance("type4", mat_leaves, base_xform * Transform3D(Basis(), Vector3(0, 0.4, 0)))

func set_view_mode(mode: String):
	if not mat_grass: return
	
	if mode == "xray":
		mat_grass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_grass.albedo_color = Color(mat_grass.albedo_color, 0.3)
		if city_root: city_root.visible = true
		if trees_root: trees_root.visible = true
	elif mode == "realistic":
		mat_grass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat_grass.albedo_color = Color(mat_grass.albedo_color, 1.0)
		if city_root: city_root.visible = true
		if trees_root: trees_root.visible = true
	elif mode == "system":
		mat_grass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_grass.albedo_color = Color(mat_grass.albedo_color, 0.0)
		if city_root: city_root.visible = false
		if trees_root: trees_root.visible = false

func _generate_track_sleepers(path_node: Path3D, mat: Material):
	if not path_node or not path_node.curve: return
	var curve = path_node.curve
	var length = curve.get_baked_length()
	var spacing = 0.5
	var count = int(length / spacing)
	
	if count <= 0: return
	
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = count
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(2.4, 0.1, 0.25)
	mesh.material = mat
	multimesh.mesh = mesh
	
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.custom_aabb = AABB(Vector3(-10000, -2000, -10000), Vector3(20000, 4000, 20000))
	mmi.name = "Sleepers_" + path_node.name
	path_node.add_child(mmi)
	
	for i in range(count):
		var offset = i * spacing
		var pos = curve.sample_baked(offset)
		var t_offset = min(offset + 0.1, length)
		var next_pos = curve.sample_baked(t_offset)
		
		var dir = Vector3.FORWARD
		if offset + 0.1 > length:
			t_offset = max(offset - 0.1, 0.0)
			var prev_pos = curve.sample_baked(t_offset)
			dir = (pos - prev_pos).normalized()
		else:
			dir = (next_pos - pos).normalized()
			
		var tr = Transform3D()
		if dir.length_squared() > 0.001 and abs(dir.y) < 0.99:
			tr = Transform3D(Basis.looking_at(dir, Vector3.UP), pos)
		else:
			tr.origin = pos
			
		tr.origin.y += 0.55 # Nổi lên rõ ràng hơn (dày 0.1, Y đi từ 0.5 đến 0.6)
		multimesh.set_instance_transform(i, tr)

func _set_visibility_range(node: Node, max_dist: float):
	if node is GeometryInstance3D:
		node.visibility_range_end = max_dist
		node.visibility_range_begin = 0.0
		node.visibility_range_end_margin = 50.0
	for child in node.get_children():
		_set_visibility_range(child, max_dist)
