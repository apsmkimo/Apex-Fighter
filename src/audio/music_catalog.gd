class_name MusicCatalog
extends Resource
## 各畫面的預設 BGM。
## 關卡用 StageData.bgm、Boss 用 BossData.bgm 覆寫；欄位空著就用這裡的曲子。
## 換音樂＝換成同名音檔，或把這份資源的欄位指到新檔。

@export var title: AudioStream
@export var ship_select: AudioStream
@export var stage: AudioStream
@export var boss: AudioStream
@export var result: AudioStream
