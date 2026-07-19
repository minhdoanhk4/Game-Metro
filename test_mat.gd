extends SceneTree
func _init():
    var mat = StandardMaterial3D.new()
    print("Default emission: ", mat.emission)
    print("Default operator: ", mat.emission_operator)
    quit()
