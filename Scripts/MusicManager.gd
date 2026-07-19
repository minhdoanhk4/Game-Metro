extends Node

var bg_player: AudioStreamPlayer
var playlist: Array[String] = []
var current_idx: int = -1
var is_muted: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	bg_player = AudioStreamPlayer.new()
	bg_player.bus = "Master"
	bg_player.finished.connect(_on_song_finished)
	add_child(bg_player)

func _load_playlist():
	playlist.clear()
	var dir = DirAccess.open("res://Assets/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("music_bg") and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
				playlist.append("res://Assets/" + file_name)
			elif file_name.begins_with("music_bg") and file_name.ends_with(".import"):
				var actual_name = file_name.replace(".import", "")
				if actual_name.ends_with(".mp3") or actual_name.ends_with(".ogg"):
					if not playlist.has("res://Assets/" + actual_name):
						playlist.append("res://Assets/" + actual_name)
			file_name = dir.get_next()
	playlist.shuffle()

func start_music():
	if playlist.is_empty():
		_load_playlist()
		if playlist.is_empty():
			print("MusicManager: No .mp3 or .ogg background music found.")
			return
			
	if not bg_player.playing:
		_play_next()

func _play_next():
	if playlist.is_empty(): return
	
	current_idx += 1
	if current_idx >= playlist.size():
		current_idx = 0
		playlist.shuffle()
		
	var stream = load(playlist[current_idx])
	if stream:
		bg_player.stream = stream
		bg_player.play()

func _on_song_finished():
	_play_next()

func _process(delta):
	if not bg_player.playing: return
	
	# Default external volume: Reduced by 40% (perceptually ~ -14 dB)
	var target_db = -14.0 
	
	var cam = get_viewport().get_camera_3d()
	if cam:
		var cname = cam.name
		# If it's an internal camera
		if cname in ["Cam_Cabin", "Cam_Car_1", "Cam_Car_2", "Cam_Car_3"]:
			# Internal volume: Reduced by 70% (perceptually ~ -24 dB)
			target_db = -24.0
			
	if is_muted:
		target_db = -80.0
			
	# Smoothly interpolate volume (speed up slightly for better responsiveness)
	bg_player.volume_db = lerp(bg_player.volume_db, float(target_db), delta * 5.0)
	
	# Debug print every 1 second
	if Engine.get_process_frames() % 60 == 0:
		print("MusicManager: cam=", cam.name if cam else "None", " target_db=", target_db, " vol=", bg_player.volume_db)

