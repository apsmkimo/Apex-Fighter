class_name ItemData
extends Resource
## 道具設定。

enum Type { POWER, BOMB, MEDAL }

@export var type: Type = Type.POWER
@export var texture: Texture2D
## 勳章分數；火力或炸彈已滿時也改給這個分數
@export var score_value := 1000
