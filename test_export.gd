extends SceneTree
func _init():
    print("START_TEST")
    var dir = DirAccess.open("res://Assets/livery/")
    if dir:
        dir.list_dir_begin()
        var f = dir.get_next()
        while f != "":
            print("FILE: ", f)
            f = dir.get_next()
    else:
        print("DIR_OPEN_FAILED")
    print("END_TEST")
    quit()
