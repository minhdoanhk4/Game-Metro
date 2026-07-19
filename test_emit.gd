extends SceneTree
func _init():
    var mat = StandardMaterial3D.new()
    print("emission_operator exists? ", "emission_operator" in mat)
    mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
    print("EMISSION_OP_MULTIPLY = ", BaseMaterial3D.EMISSION_OP_MULTIPLY)
    quit()
