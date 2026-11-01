class_name ItemData
extends Resource
## 道具設定。

## SPECIAL = 特殊武器，拿到的武器依戰機不同（ShipData.special_weapon）
enum Type { POWER, BOMB, MEDAL, WEAPON, MISSILE, SHIELD, SPECIAL }

@export var type: Type = Type.POWER
@export var texture: Texture2D
## Type = WEAPON 時，拿到後換成這把武器
@export var weapon: WeaponData
## 勳章分數；火力或炸彈已滿時也改給這個分數
@export var score_value := 1000
