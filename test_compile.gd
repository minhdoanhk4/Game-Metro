extends SceneTree

func _init():
	print("TESTING COMPILATION...")
	var scenery = load("res://Scripts/SceneryManager.gd")
	if scenery:
		print("SceneryManager.gd compiled successfully.")
	quit()
