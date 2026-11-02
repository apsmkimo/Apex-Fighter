extends Node
## 星圖截圖：MAP_CLEARED 指定已過關數
var t := 0.0
var _done := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	GameManager.selected_ship = Database.ships[0]
	GameManager.cleared_stages = int(OS.get_environment("MAP_CLEARED")) if OS.get_environment("MAP_CLEARED") != "" else 1
	var m := (load("res://src/ui/menus/star_map.tscn") as PackedScene).instantiate()
	add_child(m)

func _process(delta: float) -> void:
	t += delta
	if t > 1.5 and not _done:
		_done = true
		get_viewport().get_texture().get_image().save_png("user://shots/map.png")
		get_tree().quit()
