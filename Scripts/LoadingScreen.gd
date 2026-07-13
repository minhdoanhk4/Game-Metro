extends Control

var next_scene_path = "res://Scenes/Main.tscn"
var actual_progress = 0.0
var display_progress = 0.0
var scene_loaded = false
var loaded_scene_resource = null

func _ready():
	ResourceLoader.load_threaded_request(next_scene_path)

func _process(delta):
	if not scene_loaded:
		var progress_array = []
		var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress_array)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			actual_progress = progress_array[0] * 100.0
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			actual_progress = 100.0
			scene_loaded = true
			loaded_scene_resource = ResourceLoader.load_threaded_get(next_scene_path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Error loading Main scene!")
			set_process(false)
			return

	# Nội suy mượt mà thanh tiến trình, ép chạy ít nhất ~1.5 giây để nhìn kịp
	if display_progress < actual_progress:
		display_progress += 60.0 * delta 
		if display_progress > actual_progress:
			display_progress = actual_progress
			
	$ProgressBar.value = display_progress

	if scene_loaded and display_progress >= 100.0:
		set_process(false)
		get_tree().change_scene_to_packed(loaded_scene_resource)
