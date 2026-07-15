extends CanvasLayer

signal main_menu_play

var shop_instance: Node = null

var is_dragging_train: bool = false
var last_mouse_x: float = 0.0

@onready var game_over_panel = $GameOverPanel
@onready var reason_label = $GameOverPanel/Panel/VBoxContainer/ReasonLabel
@onready var restart_btn = $GameOverPanel/Panel/VBoxContainer/HBoxContainer/RestartBtn
@onready var quit_btn2 = $GameOverPanel/Panel/VBoxContainer/HBoxContainer/QuitBtn2

@onready var red_flash = $RedFlash

@onready var speed_label = $Dashboard/Margin/HBox/LeftSection/SpeedBox/SpeedLabel
@onready var speed_progress = $Dashboard/Margin/HBox/LeftSection/SpeedProgress
@onready var throttle_slider = $ThrottlePanel/Margin/VBox/ControlHBox/ThrottleSlider
# @onready var door_status removed
@onready var money_label = $TopBar/MoneyLabel
var passenger_label: Label = null
# @onready var info_label removed
@onready var clock_label = $TopBar/ClockPanel/ClockLabel
@onready var route_bar_panel = $RouteBarPanel
@onready var big_warning_label = $BigWarningContainer/BigWarningLabel

var warning_tween: Tween = null
var route_dots = []
var station_names = ["Bến Thành", "Nhà hát TP", "Ba Son", "Văn Thánh", "Tân Cảng", "Thảo Điền", "An Phú", "Rạch Chiếc", "Phước Long", "Bình Thái", "Thủ Đức", "Khu CNC", "ĐH QG", "Suối Tiên"]

@onready var shop_button = $ShopButton
@onready var pause_button = $PauseButton
@onready var in_game_exit_btn = $ExitButton
@onready var pause_menu_panel = $PauseMenuPanel
@onready var resume_menu_btn = $PauseMenuPanel/CenterContainer/VBoxContainer/ResumeMenuBtn
@onready var home_menu_btn = $PauseMenuPanel/CenterContainer/VBoxContainer/HomeMenuBtn
@onready var restart_menu_btn = $PauseMenuPanel/CenterContainer/VBoxContainer/RestartMenuBtn
@onready var exit_menu_btn = $PauseMenuPanel/CenterContainer/VBoxContainer/ExitMenuBtn
@onready var door_btn = $Dashboard/Margin/HBox/RightSection/DoorBtn
@onready var cam_btn = $Dashboard/Margin/HBox/RightSection/CamBtn
@onready var brake_btn = $Dashboard/Margin/HBox/RightSection/BrakeBtn
@onready var light_btn = $Dashboard/Margin/HBox/RightSection/LightBtn
@onready var horn_btn = $Dashboard/Margin/HBox/RightSection/HornBtn

# @onready var pip_subviewport = $PiP_Container/SubViewportContainer/SubViewport
# @onready var pip_camera = $PiP_Container/SubViewportContainer/SubViewport/PiPCamera
# @onready var pip_title = $PiP_Container/Title
# @onready var toggle_cam_btn = $PiP_Container/ToggleCamBtn

var train_ref: Node = null

var world_cameras = []
var current_pip_index = 0
var depot_menu_container: Control = null
var current_preview_index: int = 0
var train_name_label: Label = null
var action_btn: Button = null
var map_panel: Panel
var map_camera: Camera3D
var map_btn: Button
var is_map_open: bool = false
var is_map_panning: bool = false
var is_map_rotating: bool = false
var is_rotator_dragging: bool = false
var last_mouse_pos: Vector2
var rotator_last_pos: Vector2
var map_cam_yaw: float = 0.0
var map_cam_pitch: float = -PI/4.0
var signal_label: Label
var is_dragging_slider: bool = false
var drone_fov: float = 75.0
var drone_camera: Camera3D
# Cabin monitor variables removed


# Per-station per-lap approach state
# station_state[station_instance_id] = {
#   "warned": bool,       — yellow warning shown this approach
#   "stop_done": bool,    — stop cycle finished; suppress warning until train leaves
#   "last_dist": float    — previous frame distance (km)
# }
var station_state: Dictionary = {}
var prev_doors_open: bool = false  # tracks previous frame door state

var cached_stations: Array = []
var cached_trains: Array = []

func _get_stations() -> Array:
	if cached_stations.is_empty():
		cached_stations = get_tree().get_nodes_in_group("stations")
	return cached_stations

func _get_trains() -> Array:
	return get_tree().get_nodes_in_group("train")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.money_changed.connect(_on_money_changed)
	_on_money_changed(GameManager.money)
	
	# Symmetrical passenger label setup
	var top_bar = get_node_or_null("TopBar")
	if top_bar:
		passenger_label = Label.new()
		passenger_label.name = "PassengerLabel"
		passenger_label.anchors_preset = Control.PRESET_TOP_RIGHT
		passenger_label.anchor_left = 1.0
		passenger_label.anchor_right = 1.0
		passenger_label.offset_left = -220.0
		passenger_label.offset_top = 10.0
		passenger_label.offset_right = -20.0
		passenger_label.offset_bottom = 40.0
		passenger_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		passenger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		passenger_label.add_theme_font_size_override("font_size", 24)
		passenger_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		passenger_label.text = "Khách: 0"
		top_bar.add_child(passenger_label)
	
	GameManager.time_updated.connect(_on_time_updated)
	call_deferred("_init_route_bar")
	
	if big_warning_label:
		big_warning_label.custom_minimum_size = Vector2(550, 0)
		big_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		big_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big_warning_label.add_theme_font_size_override("font_size", 18)
	
	# Cabin monitor creation removed

	if shop_button:
		shop_button.pressed.connect(_on_depot_shop_pressed)
		
	if has_node("PauseButton"):
		pause_button.pressed.connect(_on_pause_pressed)
	if has_node("ExitButton"):
		in_game_exit_btn.pressed.connect(_on_in_game_exit_pressed)
		
	if has_node("PauseMenuPanel"):
		resume_menu_btn.pressed.connect(_on_resume_menu_pressed)
		home_menu_btn.pressed.connect(_on_home_menu_pressed)
		restart_menu_btn.pressed.connect(_on_restart_menu_pressed)
		exit_menu_btn.pressed.connect(_on_exit_menu_pressed)
		
	# Livery logic removed to use Shop.tscn
	if restart_btn: restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn2: quit_btn2.pressed.connect(_on_quit_pressed)

	if GameManager.skip_menu:
		get_tree().paused = false
		if has_node("Dashboard"): $Dashboard.show()
		if has_node("ThrottlePanel"): $ThrottlePanel.show()
		if has_node("RouteBarPanel"): $RouteBarPanel.show()
		if has_node("ShopButton"): $ShopButton.show()
		if has_node("PauseButton"): $PauseButton.show()
		if has_node("ExitButton"): $ExitButton.show()
		# Use call_deferred to emit main_menu_play because it connects to Main which might not be ready yet
		call_deferred("emit_signal", "main_menu_play")
	else:
		get_tree().paused = true
		_create_depot_menu()



	# if toggle_cam_btn:
	# 	toggle_cam_btn.pressed.connect(_on_toggle_pip_cam)


	if door_btn:
		door_btn.pressed.connect(_on_door_btn_pressed)
	if cam_btn:
		cam_btn.pressed.connect(_on_cam_btn_pressed)

	if brake_btn:
		brake_btn.pressed.connect(_on_brake_btn_pressed)

	if light_btn:
		light_btn.pressed.connect(_on_light_btn_pressed)

	if horn_btn:
		horn_btn.pressed.connect(_on_horn_btn_pressed)

	if throttle_slider:
		var img = Image.create(36, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tex = ImageTexture.create_from_image(img)
		throttle_slider.add_theme_icon_override("grabber", tex)
		throttle_slider.add_theme_icon_override("grabber_highlight", tex)
		throttle_slider.value_changed.connect(_on_throttle_slider_value_changed)
		throttle_slider.drag_started.connect(_on_slider_drag_started)
		throttle_slider.drag_ended.connect(_on_slider_drag_ended)

	# if pip_subviewport:
	# 	pip_subviewport.world_3d = get_viewport().world_3d
	# 	if "scaling_3d_scale" in pip_subviewport:
	# 		pip_subviewport.scaling_3d_scale = 0.5

	for t in _get_trains():
		if t.is_player_controlled:
			train_ref = t
			break

	var main_scene = get_tree().current_scene
	if main_scene:
		var cctv = main_scene.get_node_or_null("Camera_CCTV")
		if cctv:
			world_cameras.append({"name": "Ben Thanh Station", "node": cctv})

	# _update_pip_cam()
	_init_custom_btn_styles()
	call_deferred("_setup_overhead_cameras")
	call_deferred("_setup_drone_camera")
	
	# --- MAP UI SETUP ---
	map_btn = Button.new()
	var map_tex = preload("res://Assets/map_icon.svg")
	map_btn.icon = map_tex
	map_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_btn.custom_minimum_size = Vector2(48, 48)
	map_btn.position = Vector2(20, 60) # Top-left, below money
	apply_custom_btn_style(map_btn, Color(0.2, 0.3, 0.4))
	add_child(map_btn)
	map_btn.pressed.connect(_on_map_btn_pressed)
	
	map_panel = Panel.new()
	map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.hide()
	add_child(map_panel)
	
	var map_vp_container = SubViewportContainer.new()
	map_vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_vp_container.stretch = true
	map_panel.add_child(map_vp_container)
	
	var map_vp = SubViewport.new()
	map_vp.world_3d = get_viewport().world_3d
	map_vp_container.add_child(map_vp)
	
	map_camera = Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	map_camera.fov = 70.0
	map_camera.far = 50000.0
	map_camera.position = Vector3(0, 1000, 4250)
	map_cam_yaw = 0.0
	map_cam_pitch = -PI/3.0
	map_camera.rotation = Vector3(map_cam_pitch, map_cam_yaw, 0)
	map_vp.add_child(map_camera)
	
	var map_ui_vbox = VBoxContainer.new()
	map_ui_vbox.position = Vector2(20, 20)
	map_panel.add_child(map_ui_vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "BẢN ĐỒ TOÀN CẢNH"
	title_lbl.add_theme_font_size_override("font_size", 24)
	map_ui_vbox.add_child(title_lbl)
	
	var btn_xray = Button.new()
	btn_xray.text = "Xem Xuyên Thấu"
	btn_xray.custom_minimum_size = Vector2(250, 45)
	btn_xray.pressed.connect(func(): _set_map_view_mode("xray"))
	apply_custom_btn_style(btn_xray, Color(0.2, 0.4, 0.6))
	map_ui_vbox.add_child(btn_xray)
	
	var btn_real = Button.new()
	btn_real.text = "Xem Thực Tế"
	btn_real.custom_minimum_size = Vector2(250, 45)
	btn_real.pressed.connect(func(): _set_map_view_mode("realistic"))
	apply_custom_btn_style(btn_real, Color(0.2, 0.4, 0.6))
	map_ui_vbox.add_child(btn_real)
	
	var btn_sys = Button.new()
	btn_sys.text = "Xem Hệ Thống Tàu"
	btn_sys.custom_minimum_size = Vector2(250, 45)
	btn_sys.pressed.connect(func(): _set_map_view_mode("system"))
	apply_custom_btn_style(btn_sys, Color(0.2, 0.4, 0.6))
	map_ui_vbox.add_child(btn_sys)
	
	var btn_close_map = Button.new()
	btn_close_map.text = "Đóng Bản Đồ"
	btn_close_map.custom_minimum_size = Vector2(250, 45)
	btn_close_map.pressed.connect(_close_map)
	apply_custom_btn_style(btn_close_map, Color(0.6, 0.2, 0.2))
	map_ui_vbox.add_child(btn_close_map)
	
	var rotator_panel = Panel.new()
	rotator_panel.custom_minimum_size = Vector2(100, 100)
	rotator_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rotator_panel.offset_left = -120
	rotator_panel.offset_top = -120
	rotator_panel.offset_right = -20
	rotator_panel.offset_bottom = -20
	var r_style = StyleBoxFlat.new()
	r_style.bg_color = Color(0, 0, 0, 0.6)
	r_style.corner_radius_top_left = 50
	r_style.corner_radius_top_right = 50
	r_style.corner_radius_bottom_left = 50
	r_style.corner_radius_bottom_right = 50
	r_style.border_width_left = 2
	r_style.border_width_right = 2
	r_style.border_width_top = 2
	r_style.border_width_bottom = 2
	r_style.border_color = Color(0.8, 0.8, 0.8, 0.8)
	rotator_panel.add_theme_stylebox_override("panel", r_style)
	map_panel.add_child(rotator_panel)
	
	var r_label = Label.new()
	r_label.text = "XOAY\n360"
	r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotator_panel.add_child(r_label)
	
	rotator_panel.gui_input.connect(_on_rotator_gui_input)
	
	if speed_progress:
		var custom_speed = Control.new()
		custom_speed.name = "SpeedProgress"
		custom_speed.custom_minimum_size = Vector2(250, 24)
		custom_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var script = load("res://Scripts/Speedometer.gd")
		custom_speed.set_script(script)
		
		var parent = speed_progress.get_parent()
		var idx = speed_progress.get_index()
		parent.remove_child(speed_progress)
		speed_progress.queue_free()
		
		parent.add_child(custom_speed)
		parent.move_child(custom_speed, 0) # Move to the left of SpeedBox
		speed_progress = custom_speed

func _process(_delta):
	# Update passenger count
	var pm = get_node_or_null("/root/Main/PassengerManager")
	if passenger_label:
		if train_ref and "passenger_count" in train_ref:
			passenger_label.text = "Khách: %d" % train_ref.passenger_count
		elif pm:
			passenger_label.text = "Khách: %d" % pm.get_total_train_passengers()

	# Lazily find train
	if train_ref and train_ref.car1:
		update_route_bar(train_ref.car1.global_position.z)
		
	if not train_ref or not is_instance_valid(train_ref) or not train_ref.is_player_controlled:
		train_ref = null
		for t in _get_trains():
			if t.is_player_controlled:
				train_ref = t
				break

	if train_ref:
		if signal_label and train_ref.has_method("is_block_clear"):
			var clear = train_ref.is_block_clear()
			if clear:
				signal_label.text = "TÍN HIỆU: XANH (An Toàn)"
				signal_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			else:
				signal_label.text = "TÍN HIỆU: ĐỎ (Dừng Lại!)"
				signal_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

		var speed = train_ref.get_speed()
		speed_label.text = "%d" % int(abs(speed))
		if speed_progress:
			if "value" in speed_progress:
				speed_progress.value = abs(speed)
			if "max_speed" in train_ref and "max_value" in speed_progress:
				speed_progress.max_value = train_ref.max_speed
			
			var t_color = Color(0.2, 0.8, 1.0)
			if "Fast" in train_ref.name or "Fast" in train_ref.scene_file_path:
				t_color = Color(1.0, 0.2, 0.2) # Đỏ cho tàu nhanh
			elif "max_speed" in train_ref and train_ref.max_speed > 100:
				t_color = Color(1.0, 0.6, 0.2) # Cam
				
			if "train_color" in speed_progress:
				speed_progress.train_color = t_color
				
			speed_label.add_theme_color_override("font_color", t_color)
			
			var dash = get_node_or_null("Dashboard")
			if dash:
				var d_style = dash.get_theme_stylebox("panel")
				if d_style and d_style is StyleBoxFlat:
					d_style.border_color = t_color
					
			var t_panel = get_node_or_null("ThrottlePanel")
			if t_panel:
				var t_style = t_panel.get_theme_stylebox("panel")
				if t_style and t_style is StyleBoxFlat:
					t_style.border_color = t_color
		var t = train_ref.get_throttle()

		# ■ Door status ■
		if train_ref.doors_open:
			var flash = int(Time.get_ticks_msec() / 250) % 2 == 0
			if t > 0.01:
				train_ref.current_throttle = 0.0
				if throttle_slider:
					throttle_slider.value = 0.0
				show_message("WARNING: CLOSE DOORS BEFORE DEPARTING!")
				
		if door_btn:
			if train_ref.doors_open:
				var flash = int(Time.get_ticks_msec() / 250) % 2 == 0
				update_btn_color(door_btn, Color(0.9, 0.2, 0.2) if flash else Color(0.5, 0.1, 0.1))
			else:
				update_btn_color(door_btn, Color(0.1, 0.7, 0.1))
				

		if light_btn and train_ref:
			var headlight = train_ref.get_node_or_null("Car1/Headlight")
			if headlight and headlight.visible:
				update_btn_color(light_btn, Color(0.8, 0.7, 0.1))
			else:
				update_btn_color(light_btn, Color(0.4, 0.4, 0.45))

		if throttle_slider and not is_dragging_slider:
			throttle_slider.value = t * 100.0

		# ── Station proximity warnings (per-lap) ─────────────────────
		# Detect: doors just CLOSED while near a station → mark stop done immediately
		# This handles both normal stops and the spawn-at-station case
		if prev_doors_open and not train_ref.doors_open:
			var all_stations = _get_stations()
			for st in all_stations:
				var sid2 = st.get_instance_id()
				var d = (train_ref.car1.global_transform.origin - st.global_transform.origin).length() / 1000.0
				if d <= 0.5:
					if not station_state.has(sid2):
						station_state[sid2] = { "yellow_warned": false, "red_warned": false, "stop_done": true, "last_dist": d }
					else:
						station_state[sid2]["stop_done"] = true
						station_state[sid2]["yellow_warned"] = false
						station_state[sid2]["red_warned"] = false

		prev_doors_open = train_ref.doors_open
		_update_station_warnings(speed)

		if Input.is_action_just_pressed("toggle_door"):
			train_ref.toggle_doors()

		if drone_camera and train_ref.car1:
			var target_pos = train_ref.car1.global_position
			var forward_dir = -train_ref.car1.global_transform.basis.z.normalized()
			if not train_ref.direction_forward:
				forward_dir = -forward_dir
			var offset = -forward_dir * 25.0 + Vector3(0, 15.0, 0)
			drone_camera.global_position = drone_camera.global_position.lerp(target_pos + offset, _delta * 5.0)
			drone_camera.look_at(target_pos, Vector3.UP)

	# Cabin monitor overlay removed

	# PiP camera removed

# Cabin monitor functions removed

func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null

func _update_station_warnings(speed: float):
	var stations = _get_stations()
	var warning_shown = false

	for station in stations:
		var sid = station.get_instance_id()

		# Init state entry — use real current distance so first frame doesn't false-trigger
		if not station_state.has(sid):
			var init_dist = (train_ref.car1.global_transform.origin - station.global_transform.origin).length() / 1000.0
			station_state[sid] = { "yellow_warned": false, "red_warned": false, "stop_done": false, "last_dist": init_dist }

		var s = station_state[sid]
		var dist_km = (train_ref.car1.global_transform.origin - station.global_transform.origin).length() / 1000.0

		# ── Determine if approaching (distance decreasing) ─
		var approaching = dist_km < s["last_dist"]  # distance is getting smaller

		# ── Reset for next lap ──────────────────────────────────────
		# After stop is done AND train has driven away (distance increasing and > 150 meters), reset everything
		if s["stop_done"] and not approaching and dist_km > 0.15:
			s["yellow_warned"] = false
			s["red_warned"] = false
			s["stop_done"] = false
			station.reset_for_next_lap()

		# ── Sync stop state from station script ─────────────────────
		if station.stop_completed and not s["stop_done"]:
			s["stop_done"] = true

		s["last_dist"] = dist_km

		# ── Display warning ─────────────────────────────────────────
		# Suppress all warnings if: train is stopped at station with doors open
		# (covers the spawn-at-station case and normal station stop)
		var at_station_with_doors_open = (abs(speed) < 2.0 and train_ref.doors_open and dist_km <= 0.5)
		if at_station_with_doors_open:
			# Mark as stop done so warning won't re-appear this lap
			s["yellow_warned"] = true
			s["red_warned"] = true
			continue

		# Only show if: stop not yet done, and train is moving
		if not s["stop_done"] and abs(speed) > 0.1 and approaching:
			warning_shown = true
			if dist_km <= 0.5 and not s["red_warned"]:
				s["red_warned"] = true
				show_big_warning("STATION ZONE - MAX 10 KM/H", true)
				break
			elif dist_km <= 1.0 and dist_km > 0.5 and not s["yellow_warned"]:
				s["yellow_warned"] = true
				show_big_warning("STATION AHEAD - SLOW DOWN", false)
				break

	# No active warning - hide label (handled by tween)

# ── Helper: called when doors OPEN ─────────────────────────────────────────

func _on_shop_pressed(target_path: String = ""):
	if not is_instance_valid(shop_instance):
		var shop_scene = load("res://Scenes/Shop.tscn")
		if shop_scene:
			shop_instance = shop_scene.instantiate()
			add_child(shop_instance)
	if shop_instance:
		shop_instance.target_train_path = target_path
		shop_instance.show()
		if shop_instance.has_method("refresh_train_model"):
			shop_instance.refresh_train_model()

func _on_depot_shop_pressed():
	_on_shop_pressed(GameManager.train_list[current_preview_index]["path"])

func _unhandled_input(event):
	if depot_menu_container and is_instance_valid(depot_menu_container):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_dragging_train = true
					last_mouse_x = event.position.x
				else:
					is_dragging_train = false
		elif event is InputEventMouseMotion:
			if is_dragging_train:
				var delta_x = event.position.x - last_mouse_x
				last_mouse_x = event.position.x
				var main_scene = get_tree().current_scene
				if main_scene and main_scene.has_method("rotate_preview_camera"):
					main_scene.rotate_preview_camera(delta_x * 0.01)

func _on_quit_pressed():
	get_tree().quit()

var is_victory_mode: bool = false

func _on_restart_pressed():
	if is_victory_mode:
		is_victory_mode = false
		if train_ref and train_ref.has_method("reverse_direction"):
			train_ref.reverse_direction()
		game_over_panel.hide()
	else:
		GameManager.skip_menu = true
		get_tree().paused = false
		get_tree().reload_current_scene()

func trigger_game_over(reason: String):
	is_victory_mode = false
	if game_over_panel.visible: return
	get_tree().paused = true
	
	var title_label = game_over_panel.get_node("Panel/VBoxContainer/Label")
	if title_label:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		
	red_flash.show()
	game_over_panel.color = Color(0.2, 0, 0, 0.8)
	reason_label.text = "Lý do: " + reason
	if restart_btn:
		restart_btn.text = "Chơi lại"
	if quit_btn2:
		quit_btn2.text = "Thoát"
	game_over_panel.show()

func trigger_victory():
	is_victory_mode = true
	if game_over_panel.visible: return
	# DO NOT PAUSE the game for victory screen!
	
	var title_label = game_over_panel.get_node("Panel/VBoxContainer/Label")
	if title_label:
		title_label.text = "HOÀN THÀNH!"
		title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		
	red_flash.hide()
	game_over_panel.color = Color(0, 0.2, 0, 0.8)
	reason_label.text = "Chúc mừng! Bạn đã điều khiển tàu về đến bến cuối cùng an toàn."
	if restart_btn:
		restart_btn.text = "Đổi đầu tàu"
	if quit_btn2:
		quit_btn2.text = "Thoát"
	game_over_panel.show()

func _on_toggle_pip_cam():
	pass

func _update_pip_cam():
	pass

func _on_map_btn_pressed():
	is_map_open = true
	get_tree().paused = true
	map_panel.show()
	_set_map_view_mode("xray")
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("set_map_lighting_active"):
		main_scene.set_map_lighting_active(true)

func _close_map():
	is_map_open = false
	get_tree().paused = false
	map_panel.hide()
	_set_map_view_mode("realistic")
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("set_map_lighting_active"):
		main_scene.set_map_lighting_active(false)

func _set_map_view_mode(mode: String):
	var scenery = get_node_or_null("/root/Main/SceneryManager")
	if not scenery:
		var main_scene = get_tree().current_scene
		if main_scene:
			scenery = main_scene.get_node_or_null("SceneryManager")
	if scenery and scenery.has_method("set_view_mode"):
		scenery.set_view_mode(mode)

func _on_money_changed(new_money: int):
	money_label.text = "$ " + str(new_money)

func show_message(msg: String):
	show_big_warning(msg, true)



func _on_cam_btn_pressed():
	var event = InputEventKey.new()
	event.keycode = KEY_C
	event.pressed = true
	Input.parse_input_event(event)

func _on_throttle_slider_value_changed(val: float):
	if train_ref and is_dragging_slider:
		if train_ref.doors_open and val > 0.0:
			throttle_slider.value = 0.0
			train_ref.current_throttle = 0.0
			show_message("WARNING: CLOSE DOORS BEFORE DEPARTING!")
		else:
			train_ref.current_throttle = val / 100.0

func _on_slider_drag_started():
	is_dragging_slider = true

func _on_slider_drag_ended(value_changed: bool):
	is_dragging_slider = false

func _on_door_btn_pressed():
	if train_ref:
		if train_ref.doors_open:
			train_ref.close_doors()
		else:
			train_ref.open_doors()

func set_train(train_node):
	train_ref = train_node
	# Link slider value to current_throttle (slider max is 1.0)
	if train_ref and throttle_slider:
		throttle_slider.value = train_ref.current_throttle * 100.0

func _on_brake_btn_pressed():
	if train_ref:
		train_ref.current_throttle = 0.0
		if throttle_slider:
			throttle_slider.value = 0.0

func _on_light_btn_pressed():
	if train_ref:
		var headlight = train_ref.get_node_or_null("Car1/Headlight") as SpotLight3D
		if headlight:
			headlight.visible = !headlight.visible

func _on_horn_btn_pressed():
	if train_ref and train_ref.has_method("play_horn"):
		train_ref.play_horn()

func _init_custom_btn_styles():
	if door_btn: apply_custom_btn_style(door_btn, Color(0.1, 0.7, 0.1))
	if cam_btn: apply_custom_btn_style(cam_btn, Color(0.4, 0.4, 0.45))
	if light_btn: apply_custom_btn_style(light_btn, Color(0.4, 0.4, 0.45))
	if horn_btn: apply_custom_btn_style(horn_btn, Color(0.8, 0.5, 0.1))
	if brake_btn: apply_custom_btn_style(brake_btn, Color(0.8, 0.2, 0.2))
	_init_nav_btn_styles()

func _init_nav_btn_styles():
	var nav_color = Color(0.2, 0.3, 0.4)
	if shop_button: apply_custom_btn_style(shop_button, nav_color)
	if pause_button: apply_custom_btn_style(pause_button, nav_color)
	if in_game_exit_btn: apply_custom_btn_style(in_game_exit_btn, Color(0.6, 0.2, 0.2))
	if resume_menu_btn: apply_custom_btn_style(resume_menu_btn, Color(0.2, 0.6, 0.2))
	if home_menu_btn: apply_custom_btn_style(home_menu_btn, nav_color)
	if restart_menu_btn: apply_custom_btn_style(restart_menu_btn, nav_color)
	if exit_menu_btn: apply_custom_btn_style(exit_menu_btn, Color(0.6, 0.2, 0.2))
	if restart_btn: apply_custom_btn_style(restart_btn, Color(0.2, 0.6, 0.2))
	if quit_btn2: apply_custom_btn_style(quit_btn2, Color(0.6, 0.2, 0.2))

func apply_custom_btn_style(btn: Button, base_color: Color):
	btn.expand_icon = true # Icon tự co giãn theo nút (padding được xử lý bởi viewBox SVG)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color.darkened(0.5)
	normal.bg_color.a = 1.0 # Bỏ trong suốt để rõ ràng
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8
	normal.shadow_size = 0
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = base_color.darkened(0.2)

	var hover = normal.duplicate()
	hover.bg_color = base_color.darkened(0.3)
	hover.border_color = base_color.lightened(0.2)
	hover.shadow_size = 0

	var pressed = normal.duplicate()
	pressed.bg_color = base_color.darkened(0.1)
	pressed.border_color = base_color.lightened(0.5)
	pressed.shadow_size = 0

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	btn.add_theme_color_override("icon_normal_color", base_color.lightened(0.5))
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	
	var text_color = base_color.lightened(0.8)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

func update_btn_color(btn: Button, color: Color):
	if btn.has_theme_stylebox_override("normal"):
		var normal = btn.get_theme_stylebox("normal") as StyleBoxFlat
		normal.bg_color = color.darkened(0.3)
		normal.bg_color.a = 1.0
		normal.border_color = color
		normal.shadow_size = 0
		
		var hover = btn.get_theme_stylebox("hover") as StyleBoxFlat
		hover.bg_color = color.darkened(0.1)
		hover.bg_color.a = 1.0
		hover.border_color = color.lightened(0.2)
		hover.shadow_size = 0
		
		var pressed = btn.get_theme_stylebox("pressed") as StyleBoxFlat
		pressed.bg_color = color
		pressed.bg_color.a = 1.0
		pressed.border_color = color.lightened(0.5)
		pressed.shadow_size = 0

		btn.add_theme_color_override("icon_normal_color", Color.WHITE)
		btn.add_theme_color_override("font_color", Color.WHITE)


func _input(event):
	if is_map_open and map_camera:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					is_map_panning = true
					last_mouse_pos = event.position
				else:
					is_map_panning = false
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if event.is_pressed():
					is_map_rotating = true
					last_mouse_pos = event.position
				else:
					is_map_rotating = false
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var forward = -map_camera.global_transform.basis.z
				map_camera.position += forward * 200.0
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var forward = -map_camera.global_transform.basis.z
				map_camera.position -= forward * 200.0
		elif event is InputEventMouseMotion:
			if is_map_rotating:
				var delta_pos = event.position - last_mouse_pos
				last_mouse_pos = event.position
				
				map_cam_yaw -= delta_pos.x * 0.01
				map_cam_pitch -= delta_pos.y * 0.01
				map_cam_pitch = clamp(map_cam_pitch, -PI/2.0, PI/4.0)
				map_camera.rotation = Vector3(map_cam_pitch, map_cam_yaw, 0)
			elif is_map_panning:
				var delta_pos = event.position - last_mouse_pos
				last_mouse_pos = event.position
				
				var right = map_camera.global_transform.basis.x
				var forward = -map_camera.global_transform.basis.z
				forward.y = 0
				forward = forward.normalized()
				if forward.length() < 0.001:
					forward = -map_camera.global_transform.basis.y
					forward.y = 0
					forward = forward.normalized()
					
				var pan_speed = clamp(map_camera.position.y * 0.002, 0.5, 10.0)
				map_camera.position -= right * delta_pos.x * pan_speed
				map_camera.position += forward * delta_pos.y * pan_speed
		return

func _on_rotator_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				is_rotator_dragging = true
				rotator_last_pos = event.position
			else:
				is_rotator_dragging = false
	elif event is InputEventMouseMotion and is_rotator_dragging:
		var delta_pos = event.position - rotator_last_pos
		rotator_last_pos = event.position
		
		map_cam_yaw -= delta_pos.x * 0.01
		map_cam_pitch -= delta_pos.y * 0.01
		map_cam_pitch = clamp(map_cam_pitch, -PI/2.0, PI/4.0)
		if map_camera:
			map_camera.rotation = Vector3(map_cam_pitch, map_cam_yaw, 0)


func _setup_overhead_cameras():
	var main_scene = get_tree().current_scene
	if not main_scene: return
	
	var stations = _get_stations()
	var added_stations = []
	
	for station in stations:
		var s_name = station.station_name.to_upper()
		if s_name in added_stations:
			continue
		added_stations.append(s_name)
		
		# 1. Tạo Camera3D góc nhìn từ trên cao (SKY View)
		var cam = Camera3D.new()
		cam.name = "Camera_Sky_" + s_name
		main_scene.add_child(cam)
		
		# Xoay camera nhìn góc xéo tuỳ theo từng nhà ga
		if s_name == "BEN THANH":
			# Góc nhìn từ trên cao bao quát mặt đất (Chợ Bến Thành) và thấy được một phần hầm (nếu có khe hở)
			var offset = Vector3(60.0, 60.0, 80.0).rotated(Vector3.UP, station.rotation.y)
			cam.global_position = station.global_position + offset
			# Nhìn vào khoảng mặt đất (Y=0)
			var target = station.global_position
			target.y = 5.0
			cam.look_at(target, Vector3.UP)
		elif s_name == "BA SON":
			# Góc nhìn bao quát cầu Ba Son và nhà ga (Cầu nằm phía Z dương/âm tuỳ hướng)
			var offset = Vector3(50.0, 20.0, -90.0).rotated(Vector3.UP, station.rotation.y)
			cam.global_position = station.global_position + offset
			var target = station.global_position
			target.y = 15.0
			cam.look_at(target, Vector3.UP)
		else:
			# Các ga trên cao khác: Đặt camera hơi thấp dưới mái che, nhìn xéo góc để thấy biển hiệu và bên trong ga
			var offset = Vector3(15.0, 4.0, 30.0).rotated(Vector3.UP, station.rotation.y)
			cam.global_position = station.global_position + offset
			var target = station.global_position
			target.y = station.global_position.y + 2.0 # Nhìn vào khu vực platform
			cam.look_at(target, Vector3.UP)
		
		# 2. Tạo nhãn định vị Label3D hiển thị tên nhà ga (chỉ ga trên cao)
		if s_name != "BEN THANH" and s_name != "BA SON":
			var label = Label3D.new()
			label.name = "Label3D_Overhead_" + s_name
			label.text = station.station_name
			label.billboard = 0 # Tắt billboard, đặt nhãn cố định
			
			# Thiết lập nhãn hiển thị tên ga
			label.double_sided = true
			label.pixel_size = 0.02 # Nhỏ lại đáng kể (chiều cao ~4.0m)
			label.outline_size = 24
			label.font_size = 200 # Tăng kích thước chữ lên cỡ 200
			label.modulate = Color(0.0, 0.1, 0.4) # Chữ màu xanh Navy
			label.outline_modulate = Color.WHITE # Viền trắng nổi bật trên mái vòm
			
			# Đặt nhãn nằm sát ngay trên nóc mái của ga trên cao (nâng lên 16.0m để không bị lẹ/chìm vào mái vòm)
			var label_y = station.global_position.y + 16.0
			var target_pos = station.global_position
			target_pos.y = label_y
			
			main_scene.add_child(label)
			
			# Thiết lập basis để chữ nằm dọc theo chiều dài mái và mặt chữ hướng lên trời, không bị mirrored (mặt trước hướng lên)
			var station_basis = station.global_transform.basis
			var axis_x = -station_basis.z.normalized()
			var axis_y = -station_basis.x.normalized()
			var axis_z = station_basis.y.normalized()
			label.global_transform = Transform3D(Basis(axis_x, axis_y, axis_z), target_pos)
		
		# Thêm vào danh sách camera phụ
		world_cameras.append({
			"name": s_name + " SKY",
			"node": cam
		})
		
	# _update_pip_cam()

func _setup_drone_camera():
	var main_scene = get_tree().current_scene
	if not main_scene: return
	
	drone_camera = Camera3D.new()
	drone_camera.name = "Camera_Drone"
	main_scene.add_child(drone_camera)
	
	world_cameras.append({
		"name": "DRONE FOLLOW",
		"node": drone_camera
	})
	# _update_pip_cam()

# ----------------- NEW FEATURES -----------------

func _on_time_updated(h: int, m: int):
	if clock_label:
		clock_label.text = "%02d:%02d" % [h, m]

func _init_route_bar():
	if not route_bar_panel: return
	
	var stations = _get_stations()
	var unique_stations = []
	for s in stations:
		var n = s.station_name
		if not unique_stations.has(n):
			unique_stations.append(n)
	
	if unique_stations.size() > 0:
		station_names = unique_stations
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 25)
	route_bar_panel.add_child(hbox)
	
	for i in range(station_names.size()):
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(vbox)
		
		var lbl = Label.new()
		lbl.text = station_names[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.custom_minimum_size = Vector2(40, 30)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(lbl)
		
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		var style = StyleBoxFlat.new()
		style.bg_color = Color.GREEN
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		dot.add_theme_stylebox_override("panel", style)
		vbox.add_child(dot)
		
		route_dots.append(dot)

func show_big_warning(text: String, is_red: bool = true):
	big_warning_label.text = text
	var col = Color.RED if is_red else Color.YELLOW
	if "+" in text or "Đón trả khách" in text:
		col = Color(0.2, 0.9, 0.2) # Bright Green for rewards
	big_warning_label.add_theme_color_override("font_color", col)
	big_warning_label.visible = true
	big_warning_label.modulate.a = 1.0
	
	if warning_tween:
		warning_tween.kill()
	
	warning_tween = create_tween()
	warning_tween.tween_interval(4.0)
	warning_tween.tween_property(big_warning_label, "modulate:a", 0.0, 1.0)
	warning_tween.tween_callback(func(): big_warning_label.visible = false)

func update_route_bar(train_z: float):
	if route_dots.is_empty(): return
	var max_idx = max(0, station_names.size() - 1)
	var progress = clamp(train_z / 1500.0, 0, max_idx)
	var closest_idx = int(round(progress))
	var is_at_station = abs(progress - closest_idx) <= 0.05
	
	var forward = true
	if train_ref and "direction_forward" in train_ref:
		forward = train_ref.direction_forward
		
	var blink = int(Time.get_ticks_msec() / 500) % 2 == 0
	
	if forward:
		var passed_idx = int(floor(progress))
		if is_at_station:
			passed_idx = closest_idx
			
		for i in range(route_dots.size()):
			var dot = route_dots[i]
			var style = dot.get_theme_stylebox("panel") as StyleBoxFlat
			if not style: continue
			
			if is_at_station:
				if i <= closest_idx:
					style.bg_color = Color.GREEN
				else:
					style.bg_color = Color.GRAY
			else:
				if i <= passed_idx:
					style.bg_color = Color.GREEN
				elif i == passed_idx + 1:
					style.bg_color = Color.GREEN if blink else Color.GRAY
				else:
					style.bg_color = Color.GRAY
	else:
		var passed_idx = int(ceil(progress))
		if is_at_station:
			passed_idx = closest_idx
			
		for i in range(route_dots.size()):
			var dot = route_dots[i]
			var style = dot.get_theme_stylebox("panel") as StyleBoxFlat
			if not style: continue
			
			if is_at_station:
				if i >= closest_idx:
					style.bg_color = Color.GREEN
				else:
					style.bg_color = Color.GRAY
			else:
				if i >= passed_idx:
					style.bg_color = Color.GREEN
				elif i == passed_idx - 1:
					style.bg_color = Color.GREEN if blink else Color.GRAY
				else:
					style.bg_color = Color.GRAY

func _create_depot_menu():
	if is_instance_valid(depot_menu_container):
		depot_menu_container.queue_free()
		
	# Hide gameplay panels for a clean full-screen depot selection view
	if has_node("Dashboard"): $Dashboard.hide()
	if has_node("ThrottlePanel"): $ThrottlePanel.hide()
	if has_node("RouteBarPanel"): $RouteBarPanel.hide()
	if has_node("ShopButton"): $ShopButton.hide()
	if has_node("PauseButton"): $PauseButton.hide()
	if has_node("ExitButton"): $ExitButton.hide()
		
	depot_menu_container = Control.new()
	depot_menu_container.name = "DepotMenu"
	depot_menu_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(depot_menu_container)
	
	if has_node("TopBar"):
		$TopBar.show()
		
	var bottom_panel = Panel.new()
	bottom_panel.custom_minimum_size = Vector2(500, 220)
	bottom_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_panel.offset_left = -250
	bottom_panel.offset_top = -260
	bottom_panel.offset_right = 250
	bottom_panel.offset_bottom = -40
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 0.2)
	bottom_panel.add_theme_stylebox_override("panel", style)
	depot_menu_container.add_child(bottom_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	bottom_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "CHỌN TÀU CỦA BẠN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var btn_left = Button.new()
	btn_left.text = " < "
	btn_left.custom_minimum_size = Vector2(45, 35)
	btn_left.pressed.connect(_on_depot_left)
	hbox.add_child(btn_left)
	apply_custom_btn_style(btn_left, Color(0.1, 0.5, 0.8))
	
	train_name_label = Label.new()
	train_name_label.text = GameManager.train_list[current_preview_index]["name"]
	train_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	train_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	train_name_label.custom_minimum_size = Vector2(250, 35)
	train_name_label.add_theme_font_size_override("font_size", 18)
	train_name_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(train_name_label)
	
	var btn_right = Button.new()
	btn_right.text = " > "
	btn_right.custom_minimum_size = Vector2(45, 35)
	btn_right.pressed.connect(_on_depot_right)
	hbox.add_child(btn_right)
	apply_custom_btn_style(btn_right, Color(0.1, 0.5, 0.8))
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)
	
	action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(180, 45)
	action_btn.pressed.connect(_on_depot_action)
	btn_hbox.add_child(action_btn)
	
	var depot_shop_btn = Button.new()
	depot_shop_btn.text = "MÀU SƠN (LIVERY)"
	depot_shop_btn.custom_minimum_size = Vector2(180, 45)
	depot_shop_btn.pressed.connect(_on_depot_shop_pressed)
	btn_hbox.add_child(depot_shop_btn)
	apply_custom_btn_style(depot_shop_btn, Color(0.8, 0.4, 0.15))
	
	var quit_btn_d = Button.new()
	quit_btn_d.text = "THOÁT GAME"
	quit_btn_d.custom_minimum_size = Vector2(150, 35)
	quit_btn_d.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quit_btn_d.offset_left = -170
	quit_btn_d.offset_top = -65
	quit_btn_d.offset_right = -20
	quit_btn_d.offset_bottom = -30
	quit_btn_d.pressed.connect(func(): get_tree().quit())
	depot_menu_container.add_child(quit_btn_d)
	apply_custom_btn_style(quit_btn_d, Color(0.6, 0.2, 0.2))
	
	_update_depot_menu_ui()

func _update_depot_menu_ui():
	var train = GameManager.train_list[current_preview_index]
	train_name_label.text = train["name"]
	
	var owned = GameManager.is_train_owned(current_preview_index)
	if owned:
		action_btn.text = "CHỌN TÀU"
		apply_custom_btn_style(action_btn, Color(0.1, 0.7, 0.1))
		action_btn.disabled = false
	else:
		action_btn.text = "🔒 MỞ KHÓA - $" + str(train["price"])
		var can_afford = GameManager.money >= train["price"]
		if can_afford:
			apply_custom_btn_style(action_btn, Color(0.8, 0.5, 0.1))
			action_btn.disabled = false
		else:
			apply_custom_btn_style(action_btn, Color(0.4, 0.4, 0.45))
			action_btn.disabled = true
			
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("_spawn_preview_train"):
		main_scene._spawn_preview_train(current_preview_index)

func _on_depot_left():
	current_preview_index -= 1
	if current_preview_index < 0:
		current_preview_index = GameManager.train_list.size() - 1
	_update_depot_menu_ui()

func _on_depot_right():
	current_preview_index += 1
	if current_preview_index >= GameManager.train_list.size():
		current_preview_index = 0
	_update_depot_menu_ui()

func _on_depot_action():
	var owned = GameManager.is_train_owned(current_preview_index)
	if owned:
		GameManager.select_train(current_preview_index)
		if is_instance_valid(depot_menu_container):
			depot_menu_container.queue_free()
		
		# Show gameplay panels
		if has_node("Dashboard"): $Dashboard.show()
		if has_node("ThrottlePanel"): $ThrottlePanel.show()
		if has_node("RouteBarPanel"): $RouteBarPanel.show()
		if has_node("ShopButton"): $ShopButton.show()
		if has_node("PauseButton"): $PauseButton.show()
		if has_node("ExitButton"): $ExitButton.show()
		if has_node("TopBar"): $TopBar.show()
			
		get_tree().paused = false
		main_menu_play.emit()
	else:
		var success = GameManager.unlock_train(current_preview_index)
		if success:
			_update_depot_menu_ui()
			show_message("Đã mở khóa thành công " + GameManager.train_list[current_preview_index]["name"] + "!")

func _on_pause_pressed():
	get_tree().paused = true
	pause_menu_panel.show()

func _on_resume_menu_pressed():
	get_tree().paused = false
	pause_menu_panel.hide()

func _on_home_menu_pressed():
	get_tree().paused = false
	GameManager.skip_menu = false
	get_tree().reload_current_scene()

func _on_restart_menu_pressed():
	_on_restart_pressed()

func _on_exit_menu_pressed():
	get_tree().quit()

func _on_in_game_exit_pressed():
	get_tree().quit()
