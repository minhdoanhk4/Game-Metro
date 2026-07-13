extends SceneTree
func _init():
    print("LOAD_TEST")
    var tex = load("res://Assets/livery/LNCV_LaNgocCanhVang.jpg")
    if tex:
        print("SUCCESS_TEX: ", tex)
    else:
        print("FAILED_LOAD")
    var f = FileAccess.open("res://Assets/livery/LNCV_LaNgocCanhVang.jpg.import", FileAccess.READ)
    if f:
        print("IMPORT_FILE_EXISTS")
    else:
        print("IMPORT_FILE_MISSING")
    print("END_TEST")
    quit()
