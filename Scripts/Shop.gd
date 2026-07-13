extends CanvasLayer

@onready var money_label = $TopBar/MoneyLabel
@onready var prev_button = $TopBar/HBoxContainer/PrevButton
@onready var next_button = $TopBar/HBoxContainer/NextButton
@onready var livery_name_label = $TopBar/HBoxContainer/LiveryNameLabel
@onready var close_button = $TopBar/CloseButton
@onready var buy_apply_button = $BottomBar/BuyApplyButton

@onready var train_pivot = $PreviewFrame/ViewportContainer/SubViewport/TrainPivot
@onready var sub_viewport = $PreviewFrame/ViewportContainer/SubViewport

var preview_train: Node = null

var liveries: Array[String] = []
var current_index: int = 0
var livery_cost: int = 50
var target_train_path: String = ""

var is_dragging: bool = false
var last_mouse_x: float = 0.0

func _ready():
	_load_liveries()
	
	GameManager.money_changed.connect(_on_money_changed)
	_on_money_changed(GameManager.money)
	
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	buy_apply_button.pressed.connect(_on_buy_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	var shop_cam = $PreviewFrame/ViewportContainer/SubViewport/Camera3D
	if shop_cam:
		shop_cam.make_current()
		shop_cam.position = Vector3(15, 3, 12)
		shop_cam.look_at(Vector3(0, 1, 0), Vector3.UP)
	
	refresh_train_model()
	_update_shop_ui()

func refresh_train_model():
	if not is_instance_valid(train_pivot): return
	
	# Xoá tàu cũ
	for child in train_pivot.get_children():
		child.queue_free()
		
	var path = target_train_path if target_train_path != "" else GameManager.get_current_train_path()
	var res = load(path)
	if res:
		var dummy_path = Path3D.new()
		var curve = Curve3D.new()
		curve.add_point(Vector3(0, 0, -50))
		curve.add_point(Vector3(0, 0, 50))
		dummy_path.curve = curve
		train_pivot.add_child(dummy_path)
		
		preview_train = res.instantiate()
		preview_train.is_preview = true
		preview_train.is_player_controlled = false
		preview_train.process_mode = Node.PROCESS_MODE_ALWAYS
		if "train_progress" in preview_train:
			preview_train.train_progress = 50.0
			
		dummy_path.add_child(preview_train)
		
		# Đảm bảo camera của Shop được kích hoạt lại để camera trong tàu không chiếm quyền
		var shop_cam = sub_viewport.get_node_or_null("Camera3D")
		if shop_cam:
			shop_cam.make_current()
	
	train_pivot.rotation.y = 0.0
	is_dragging = false
	
	# Cập nhật lại current_index theo livery của tàu hiện tại (nếu người chơi vừa đổi tàu)
	if liveries.size() > 0:
		var t_path = target_train_path if target_train_path != "" else GameManager.get_current_train_path()
		var applied_livery = GameManager.get_current_livery(t_path)
		var found_idx = liveries.find(applied_livery)
		current_index = found_idx if found_idx != -1 else 0
	
	_update_shop_ui()

func _load_liveries():
	# Allow empty livery (default)
	liveries.append("")
	
	var path = "res://Assets/livery/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".remap", "").replace(".import", "")
				if clean_name.ends_with(".jpg") or clean_name.ends_with(".png"):
					if not liveries.has(clean_name):
						liveries.append(clean_name)
			file_name = dir.get_next()
			
	# Find current livery index
	var t_path = target_train_path if target_train_path != "" else GameManager.get_current_train_path()
	current_index = liveries.find(GameManager.get_current_livery(t_path))
	if current_index == -1:
		current_index = 0

func _on_money_changed(m):
	money_label.text = "Tiền: $" + str(m)
	_update_buy_button()

func _update_shop_ui():
	var current_livery = liveries[current_index]
	if current_livery == "":
		livery_name_label.text = "Mặc định"
	else:
		# e.g. VNA_VietnamAirline.jpg -> VNA_VietnamAirline
		livery_name_label.text = current_livery.replace(".jpg", "").replace(".png", "")
		
	_update_buy_button()
	
	if preview_train and preview_train.has_method("apply_livery"):
		preview_train.apply_livery(current_livery)

func _update_buy_button():
	var current_livery = liveries[current_index]
	if current_livery == "" or GameManager.owned_liveries.has(current_livery):
		buy_apply_button.text = "Áp Dụng"
		buy_apply_button.disabled = false
	else:
		buy_apply_button.text = "Mua ($" + str(livery_cost) + ")"
		buy_apply_button.disabled = GameManager.money < livery_cost

func _on_prev_pressed():
	current_index -= 1
	if current_index < 0:
		current_index = liveries.size() - 1
	_update_shop_ui()

func _on_next_pressed():
	current_index += 1
	if current_index >= liveries.size():
		current_index = 0
	_update_shop_ui()

func _on_buy_apply_pressed():
	var current_livery = liveries[current_index]
	var t_path = target_train_path if target_train_path != "" else GameManager.get_current_train_path()
	if current_livery == "" or GameManager.owned_liveries.has(current_livery):
		GameManager.apply_livery(current_livery, t_path)
		hide()
	else:
		if GameManager.buy_livery(current_livery, livery_cost):
			GameManager.apply_livery(current_livery, t_path)
			hide()

func _on_close_pressed():
	hide()

func _input(event):
	if not visible:
		return
		
	if event is InputEventMouseButton:
		var local_pos = $PreviewFrame.get_local_mouse_position()
		if Rect2(Vector2(), $PreviewFrame.size).has_point(local_pos):
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_dragging = true
					last_mouse_x = event.position.x
				else:
					is_dragging = false
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				var shop_cam = sub_viewport.get_node_or_null("Camera3D")
				if shop_cam: shop_cam.fov = max(30.0, shop_cam.fov - 5.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				var shop_cam = sub_viewport.get_node_or_null("Camera3D")
				if shop_cam: shop_cam.fov = min(90.0, shop_cam.fov + 5.0)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				is_dragging = false
	elif event is InputEventMouseMotion:
		if is_dragging:
			var delta_x = event.position.x - last_mouse_x
			last_mouse_x = event.position.x
			train_pivot.rotation.y -= delta_x * 0.01

func _notification(what):
	if what == 31: # NOTIFICATION_VISIBILITY_CHANGED
		if visible:
			refresh_train_model()
