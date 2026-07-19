extends SceneTree

func _init():
	var env = Environment.new()
	print("Has background_energy_multiplier? ", "background_energy_multiplier" in env)
	print("Has background_energy? ", "background_energy" in env)
	print("Has background_intensity? ", "background_intensity" in env)
	print("Properties:")
	for p in env.get_property_list():
		if "energy" in p.name or "intensity" in p.name:
			print(" - ", p.name)
	quit()
