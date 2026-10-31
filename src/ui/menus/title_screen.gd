extends Control
## 標題畫面。


func _ready() -> void:
	UiKit.background(self)
	var col := UiKit.centered_column(self, 40)
	col.add_child(UiKit.label("APEX FIGHTER", 84, UiKit.ACCENT))
	col.add_child(UiKit.label("HI SCORE  %d" % GameManager.hi_score, 30, Color(1, 0.85, 0.4)))
	var start := UiKit.button("START")
	start.pressed.connect(GameManager.goto_ship_select)
	col.add_child(start)
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		var quit := UiKit.button("QUIT")
		quit.pressed.connect(get_tree().quit)
		col.add_child(quit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
