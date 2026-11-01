extends Node
## 截圖工具（需要有畫面的環境，例如 xvfb-run）：跑關卡並在指定時間存截圖到 user://shots/。
## 執行：xvfb-run godot --rendering-method gl_compatibility --path . res://tests/screenshot.tscn

const SHOTS := [1.0, 7.0, 8.15, 20.0]
var t := 0.0
var _i := 0
var _boosted := false
var _hit := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	var ship: Resource = Database.ships[0]
	for s in Database.ships:
		if String(s.id) == OS.get_environment("SMOKE_SHIP"):
			ship = s
	GameManager.start_run(ship, Database.first_stage())
	add_child((load(GameManager.SCENE_STAGE) as PackedScene).instantiate())


func _process(delta: float) -> void:
	t += delta
	var p := Player.instance
	if p:
		p.invincible = 999.0
		if t > 6.0 and not _boosted:
			_boosted = true
			for i in 6:
				GameManager.add_power()
			GameManager.add_missile()
			p.add_shield()
		if t > 8.0 and not _hit:
			_hit = true
			p.invincible = 0.0
			p.take_hit(2)   # 被護盾擋下
			p.invincible = 0.0
			p.take_hit(2)
			p.invincible = 999.0
	if _i < SHOTS.size() and t >= SHOTS[_i]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shots/shot_%d.png" % _i)
		print("[shot] ", _i)
		_i += 1
		if _i >= SHOTS.size():
			get_tree().quit()
