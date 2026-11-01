class_name Item
extends Area2D
## 道具：火力升級、炸彈、勳章。被玩家的拾取範圍碰到就生效。

const SCENE_PATH := "res://src/entities/items/item.tscn"

var data: ItemData
var velocity := Vector2(0, -160)

@onready var sprite: Sprite2D = $Sprite2D


static func spawn(item_data: ItemData, pos: Vector2, parent: Node) -> void:
	var item := (load(SCENE_PATH) as PackedScene).instantiate() as Item
	item.data = item_data
	item.position = pos
	parent.add_child.call_deferred(item)


func _ready() -> void:
	sprite.texture = data.texture
	velocity.x = randf_range(-60.0, 60.0)


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + 300.0 * delta, 140.0)  # 先往上彈再慢慢往下掉
	position += velocity * delta
	var w := get_viewport_rect().size.x
	if position.x < 20.0 or position.x > w - 20.0:
		velocity.x = -velocity.x
		position.x = clampf(position.x, 20.0, w - 20.0)
	sprite.rotation = sin(Time.get_ticks_msec() * 0.004) * 0.25
	if position.y > get_viewport_rect().size.y + 60.0:
		queue_free()


func collect() -> void:
	var info := _fx_info()
	Events.item_collected.emit(info[0], global_position, info[1])
	match data.type:
		ItemData.Type.POWER:
			if not GameManager.add_power():
				GameManager.add_score(data.score_value)
		ItemData.Type.BOMB:
			if not GameManager.add_bomb():
				GameManager.add_score(data.score_value)
		ItemData.Type.WEAPON:
			if not GameManager.pick_weapon(data.weapon):
				GameManager.add_score(data.score_value)
		ItemData.Type.MISSILE:
			if not GameManager.add_missile():
				GameManager.add_score(data.score_value)
		ItemData.Type.SPECIAL:
			var sw := GameManager.selected_ship.special_weapon if GameManager.selected_ship else null
			if not GameManager.pick_weapon(sw):
				GameManager.add_score(data.score_value)
		ItemData.Type.SHIELD:
			if Player.instance:
				Player.instance.add_shield()
		ItemData.Type.MEDAL:
			GameManager.add_score(data.score_value)
	queue_free()


## 撿道具時飛出的文字與光環顏色
func _fx_info() -> Array:
	match data.type:
		ItemData.Type.POWER:
			return ["POWER UP", Color(1.0, 0.45, 0.4)]
		ItemData.Type.BOMB:
			return ["BOMB +1", Color(0.45, 1.0, 0.55)]
		ItemData.Type.WEAPON, ItemData.Type.SPECIAL:
			var w := data.weapon
			if data.type == ItemData.Type.SPECIAL and GameManager.selected_ship:
				w = GameManager.selected_ship.special_weapon
			if w and GameManager.weapon == w:
				return ["POWER UP", WeaponData.ui_color(w)]
			if w:
				return [w.display_name.to_upper(), WeaponData.ui_color(w)]
		ItemData.Type.MISSILE:
			return ["MISSILE +1", Color(0.75, 0.45, 1.0)]
		ItemData.Type.SHIELD:
			return ["SHIELD", Color(0.35, 0.85, 1.0)]
		ItemData.Type.MEDAL:
			return ["+%d" % data.score_value, Color(1.0, 0.8, 0.3)]
	return ["", Color.WHITE]
