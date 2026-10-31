class_name HealthComponent
extends Node
## 血量組件：任何會被打的東西都可以掛一個。

signal damaged(amount: int, current: int)
signal died

@export var max_hp := 1
var hp := 1
var dead := false


func setup(value: int) -> void:
	max_hp = maxi(value, 1)
	hp = max_hp
	dead = false


func take_damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(hp - amount, 0)
	damaged.emit(amount, hp)
	if hp == 0:
		dead = true
		died.emit()


func ratio() -> float:
	return float(hp) / float(max_hp)
