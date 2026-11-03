class_name GroundDecal
extends Sprite2D
## 地表上的坑洞（砲台被摧毀後留下），跟著地表捲動，離開畫面就刪除。


static func spawn(tex: Texture2D, pos: Vector2, parent: Node) -> void:
	if tex == null or parent == null or not is_instance_valid(parent):
		return
	var d := GroundDecal.new()
	d.texture = tex
	d.position = pos
	d.rotation = randf() * TAU
	d.z_index = -6
	parent.add_child.call_deferred(d)


var _age := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	position.y += ScrollBackground.ground_speed * delta
	# 剛炸完的前 3 秒冒煙
	if _age < 3.0 and NeonFx.instance and Engine.get_physics_frames() % 4 == 0:
		NeonFx.instance.emit(global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
				Vector2(randf_range(-15, 15), -40), 0.9, 10.0, Color(0.5, 0.5, 0.5, 0.5))
	if position.y > get_viewport_rect().size.y + 160.0:
		queue_free()
