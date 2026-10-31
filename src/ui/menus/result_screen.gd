extends Control
## 結算畫面：過關或遊戲結束。


func _ready() -> void:
	UiKit.background(self)
	var col := UiKit.centered_column(self, 32)
	if GameManager.last_run_cleared:
		col.add_child(UiKit.label("STAGE CLEAR!", 72, Color(0.5, 1, 0.7)))
	else:
		col.add_child(UiKit.label("GAME OVER", 72, Color(1, 0.4, 0.4)))
	if GameManager.difficulty:
		col.add_child(UiKit.label(GameManager.difficulty.display_name, 32, GameManager.difficulty.color))
	col.add_child(UiKit.label("SCORE  %d" % GameManager.score, 40))
	col.add_child(UiKit.label("HI SCORE  %d" % GameManager.hi_score, 32, Color(1, 0.85, 0.4)))
	var retry := UiKit.button("RETRY")
	retry.pressed.connect(_retry)
	col.add_child(retry)
	var ships := UiKit.button("CHANGE SHIP")
	ships.pressed.connect(GameManager.goto_ship_select)
	col.add_child(ships)
	var title := UiKit.button("TITLE")
	title.pressed.connect(GameManager.goto_title)
	col.add_child(title)


func _retry() -> void:
	GameManager.start_run(GameManager.selected_ship, GameManager.current_stage)
	GameManager.goto_stage()
