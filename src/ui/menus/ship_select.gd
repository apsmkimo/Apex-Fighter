extends Control
## 選機畫面：自動列出 Database.ships 的所有戰機。
## 之後新增戰機只要在 data/ships/ 加 .tres，這裡會自動多一個選項。

var _selected: ShipData
var _preview: TextureRect
var _name: Label
var _desc: Label
var _stats: Label
var _list: HBoxContainer


func _ready() -> void:
	UiKit.background(self)
	var col := UiKit.centered_column(self, 28)
	col.add_child(UiKit.label("SELECT YOUR SHIP", 48, UiKit.ACCENT))

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(200, 250)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(_preview)
	_name = UiKit.label("", 44)
	col.add_child(_name)
	_desc = UiKit.label("", 24, Color(0.8, 0.85, 0.95))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(560, 0)
	col.add_child(_desc)
	_stats = UiKit.label("", 24, Color(1, 0.85, 0.5))
	col.add_child(_stats)

	_list = HBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override(&"separation", 16)
	col.add_child(_list)
	for ship in Database.ships:
		var b := Button.new()
		b.icon = ship.texture
		b.expand_icon = true
		b.custom_minimum_size = Vector2(120, 140)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not ship.unlocked
		b.pressed.connect(_select.bind(ship))
		_list.add_child(b)

	var start := UiKit.button("LAUNCH")
	start.pressed.connect(_launch)
	col.add_child(start)
	var back := UiKit.button("BACK", 30, Vector2(360, 80))
	back.pressed.connect(GameManager.goto_title)
	col.add_child(back)

	var initial := GameManager.selected_ship if GameManager.selected_ship else (Database.ships[0] if not Database.ships.is_empty() else null)
	if initial:
		_select(initial)


func _select(ship: ShipData) -> void:
	_selected = ship
	_preview.texture = ship.texture
	_name.text = ship.display_name
	_desc.text = ship.description
	var weapon_name := ship.weapon.display_name if ship.weapon else "-"
	_stats.text = "SPEED %d   LIFE %d   BOMB %d\nWEAPON  %s" % [int(ship.speed), ship.start_lives, ship.start_bombs, weapon_name]
	for i in _list.get_child_count():
		(_list.get_child(i) as Button).button_pressed = Database.ships[i] == ship


func _launch() -> void:
	if _selected == null:
		return
	GameManager.start_run(_selected, Database.first_stage())
	GameManager.goto_stage()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.goto_title()
