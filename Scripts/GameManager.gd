extends Node

# Economy
var money: int = 100
var score: int = 0
var skip_menu: bool = false
var pass_by_pass: bool = false

var click_audio: AudioStreamPlayer

# Time System
var time_hours: float = 6.0
var time_scale: float = 12.0 # 12x faster: 2 real hours = 24 game hours
signal time_updated(hours: int, minutes: int)

var _last_emitted_minute: int = -1

func _process(delta):
	time_hours += (delta / 3600.0) * time_scale
	if time_hours >= 24.0:
		time_hours -= 24.0
		
	var h = int(time_hours)
	var m = int((time_hours - h) * 60)
	
	if m != _last_emitted_minute:
		_last_emitted_minute = m
		time_updated.emit(h, m)

func _ready():
	_setup_click_audio()
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_recursive(get_tree().root)

func _setup_click_audio():
	click_audio = AudioStreamPlayer.new()
	add_child(click_audio)
	if ResourceLoader.exists("res://Assets/click_sound.wav"):
		click_audio.stream = load("res://Assets/click_sound.wav")

func _connect_buttons_recursive(node: Node):
	if node is Button:
		_on_node_added(node)
	for child in node.get_children():
		_connect_buttons_recursive(child)

func _on_node_added(node: Node):
	if node is Button:
		var is_hud = false
		var is_popup = false
		var parent = node
		while parent != null:
			if parent.name == "HUD" or parent.name == "HUDPanel":
				is_hud = true
			if "Panel" in parent.name:
				is_popup = true
			parent = parent.get_parent()
			
		# Play click sound if not in HUD, OR if it's inside a pop-up Panel in the HUD
		if not is_hud or is_popup:
			if not node.pressed.is_connected(play_click_sound):
				node.pressed.connect(play_click_sound)

func play_click_sound():
	if click_audio and click_audio.stream:
		click_audio.play()

# Player Inventory
var owned_trains: Array[String] = ["res://Scenes/Train.tscn", "res://Scenes/TrainFast.tscn"]
var current_train_index: int = 0

var train_list = [
	{
		"name": "Tàu Metro Xanh",
		"path": "res://Scenes/Train.tscn",
		"price": 0
	},
	{
		"name": "Tàu Metro Đỏ",
		"path": "res://Scenes/TrainFast.tscn",
		"price": 0
	},
	{
		"name": "Tàu Shinkansen",
		"path": "res://Scenes/TrainShinkansen.tscn",
		"price": 5000
	},
	{
		"name": "Tàu Cát Linh",
		"path": "res://Scenes/TrainCatLinh.tscn",
		"price": 3000
	}
]

func is_train_owned(idx: int) -> bool:
	if idx < 0 or idx >= train_list.size():
		return false
	return owned_trains.has(train_list[idx]["path"])

func unlock_train(idx: int) -> bool:
	if idx < 0 or idx >= train_list.size():
		return false
	var t = train_list[idx]
	if money >= t["price"] and not owned_trains.has(t["path"]):
		money -= t["price"]
		owned_trains.append(t["path"])
		money_changed.emit(money)
		return true
	return false

# Active Session Trains
var player_train_path: String = "res://Scenes/Train.tscn"
var ai_train_path: String = "res://Scenes/TrainFast.tscn"

signal money_changed(new_amount)
signal score_changed(new_score)

func add_money(amount: int):
	money += amount
	money_changed.emit(money)

func add_score(amount: int):
	score += amount
	score_changed.emit(score)

func buy_train(train_path: String, cost: int) -> bool:
	if money >= cost and not owned_trains.has(train_path):
		money -= cost
		owned_trains.append(train_path)
		money_changed.emit(money)
		return true
	return false

func select_train(index: int):
	if index >= 0 and index < train_list.size():
		current_train_index = index
		player_train_path = train_list[index]["path"]
		
		# Auto-assign a different train for AI
		if index == 0:
			ai_train_path = train_list[1]["path"]
		else:
			ai_train_path = train_list[0]["path"]

func set_train_selection(player_is_train_1: bool):
	select_train(0 if player_is_train_1 else 1)

func get_current_train_path() -> String:
	return player_train_path

func get_ai_train_path() -> String:
	return ai_train_path
