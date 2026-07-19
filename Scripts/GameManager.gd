extends Node

# Economy
var money: int = 100
var score: int = 0
var skip_menu: bool = false


var click_audio: AudioStreamPlayer

# Time System
var time_hours: float = 6.0
var time_scale: float = 1.0 # 1:1 real-time: 1 real hour = 1 game hour
signal time_updated(hours: int, minutes: int)

var _last_emitted_minute: int = -1
var last_player_terminal_departure_time: float = -1.0

func _process(delta):
	var time_dict = Time.get_time_dict_from_system()
	var h = time_dict["hour"]
	var m = time_dict["minute"]
	var s = time_dict["second"]
	
	time_hours = h + (m / 60.0) + (s / 3600.0)
	
	if m != _last_emitted_minute:
		_last_emitted_minute = m
		time_updated.emit(h, m)

func get_save_path() -> String:
	if not OS.has_feature("editor"):
		return OS.get_executable_path().get_base_dir().path_join("savegame.save")
	return "user://savegame.save"

func save_game():
	var save_dict = {
		"owned_trains": owned_trains,
		"owned_liveries": owned_liveries,
		"train_liveries": train_liveries,
		"current_train_index": current_train_index
	}
	var file = FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()

func load_game():
	money = 100
	score = 0
	var path = get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			var json = JSON.new()
			var error = json.parse(json_string)
			if error == OK:
				var data = json.get_data()
				
				if data.has("owned_trains"):
					owned_trains.clear()
					for t in data["owned_trains"]:
						owned_trains.append(String(t))
						
				if data.has("owned_liveries"):
					owned_liveries.clear()
					for l in data["owned_liveries"]:
						owned_liveries.append(String(l))
						
				if data.has("train_liveries"):
					train_liveries = data["train_liveries"]
					
				if data.has("current_train_index"):
					select_train(int(data["current_train_index"]))
					
			file.close()

func _init():
	var time_dict = Time.get_time_dict_from_system()
	time_hours = time_dict["hour"] + (time_dict["minute"] / 60.0) + (time_dict["second"] / 3600.0)

func _ready():
	load_game()
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
		save_game()
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
	save_game()
	money_changed.emit(money)

func add_score(amount: int):
	score += amount
	save_game()
	score_changed.emit(score)

func buy_train(train_path: String, cost: int) -> bool:
	if money >= cost and not owned_trains.has(train_path):
		money -= cost
		owned_trains.append(train_path)
		save_game()
		money_changed.emit(money)
		return true
	return false

var owned_liveries: Array[String] = []
var train_liveries: Dictionary = {}
signal livery_changed(train_path: String, new_livery: String)

func buy_livery(livery_name: String, cost: int) -> bool:
	if money >= cost and not owned_liveries.has(livery_name):
		money -= cost
		owned_liveries.append(livery_name)
		save_game()
		money_changed.emit(money)
		return true
	return false

func apply_livery(livery_name: String, train_path: String = ""):
	if train_path == "":
		train_path = get_current_train_path()
	train_liveries[train_path] = livery_name
	save_game()
	livery_changed.emit(train_path, livery_name)

func get_current_livery(train_path: String = "") -> String:
	if train_path == "":
		train_path = get_current_train_path()
	if train_liveries.has(train_path):
		return train_liveries[train_path]
	return ""


func select_train(index: int):
	if index >= 0 and index < train_list.size():
		current_train_index = index
		player_train_path = train_list[index]["path"]
		
		# Auto-assign a different train for AI
		if index == 0:
			ai_train_path = train_list[1]["path"]
		else:
			ai_train_path = train_list[0]["path"]
		save_game()

func set_train_selection(player_is_train_1: bool):
	select_train(0 if player_is_train_1 else 1)

func get_current_train_path() -> String:
	return player_train_path

func get_ai_train_path() -> String:
	return ai_train_path
