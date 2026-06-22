extends SceneTree

func _init():
    var scene = preload("res://Scenes/TrainShinkansen.tscn").instantiate()
    var car1 = scene.get_node("Car1/Body")
    if car1:
        var mesh = car1.get_meshes()[1]
        var aabb = mesh.get_aabb()
        print("Car1 Body AABB: ", aabb)
        print("Car1 Body Polygon: ", car1.polygon)
        print("Car1 Body Depth: ", car1.depth)
        
    var car6 = scene.get_node("Car6/Body")
    if car6:
        var mesh = car6.get_meshes()[1]
        var aabb = mesh.get_aabb()
        print("Car6 Body AABB: ", aabb)
    
    quit()
