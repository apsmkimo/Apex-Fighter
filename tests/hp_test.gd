extends Node
## 血量／護盾／無上限火力的單元測試。
## 執行：godot --headless --fixed-fps 60 res://tests/hp_test.tscn

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print("[hp] %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		_fails += 1


func _run() -> void:
	# SMCPKG_SUPPORT>>>CursorM9AudioTest
	_check(AudioServer.get_bus_index(&"BGM") > 0, "BGM bus")
	_check(AudioServer.get_bus_index(&"SFX") > 0, "SFX bus")
	var ui_wav := load("res://assets/audio/sfx/ui.wav") as AudioStreamWAV
	var title_wav := load("res://assets/audio/bgm/title.wav") as AudioStreamWAV
	_check(ui_wav != null and ui_wav.data.size() > 0, "ui wav imported")
	_check(title_wav != null and title_wav.get_length() > 1.0, "title bgm imported")
	ui_wav = null
	title_wav = null
	AudioManager.set_linear("BGM", 0.42)
	GameManager._save()
	var cfg := ConfigFile.new()
	_check(cfg.load(GameManager.SAVE_PATH) == OK, "save file written")
	_check(is_equal_approx(float(cfg.get_value("audio", "bgm", -1.0)), 0.42), "bgm volume kept in save")
	_check(cfg.has_section("score"), "score section still in save")
	cfg = null
	AudioManager.set_linear("BGM", 0.7)
	AudioManager.play_sfx(&"ui")
	Events.music_requested.emit(&"title")
	Events.weapon_fired.emit(&"vulcan", &"bullet")
	# SMCPKG_SUPPORT<<<CursorM9AudioTestEnd
	GameManager.start_run(Database.ships[0], Database.first_stage())
	add_child((load(GameManager.SCENE_STAGE) as PackedScene).instantiate())
	await get_tree().create_timer(2.0).timeout
	var p := Player.instance
	_check(p != null and p.alive, "player spawned")
	_check(p.hp == 6, "hp starts at 6")
	# 一般子彈 2：擋 3 發
	for i in 2:
		p.invincible = 0.0
		p.take_hit(2)
	_check(p.alive and p.hp == 2, "2 normal hits -> hp 2, alive")
	var lives := GameManager.lives
	p.invincible = 0.0
	p.take_hit(2)
	_check(not p.alive and GameManager.lives == lives - 1, "3rd normal hit -> lose a life")
	await get_tree().create_timer(2.5).timeout
	_check(p.alive and p.hp == 6, "respawn with full hp")
	# Boss 子彈 3：擋 2 發
	p.invincible = 0.0
	p.take_hit(3)
	_check(p.alive and p.hp == 3, "1 boss hit -> hp 3")
	p.invincible = 0.0
	p.take_hit(3)
	_check(not p.alive, "2nd boss hit -> lose a life")
	await get_tree().create_timer(2.5).timeout
	# 大絕招 4：滿血擋一次
	p.invincible = 0.0
	p.take_hit(4)
	_check(p.alive and p.hp == 2, "ultimate from full -> survive with 2")
	# 護盾抵銷一次
	p.add_shield()
	_check(p.shield == 20.0, "shield 20s")
	p.invincible = 0.0
	p.take_hit(4)
	_check(p.alive and p.hp == 2 and p.shield == 0.0, "shield absorbs one hit")
	# 無上限
	for i in 12:
		GameManager.add_power()
		GameManager.add_missile()
	_check(GameManager.power_level == 12, "power level 12 (no cap)")
	var w: WeaponData = GameManager.weapon
	_check(w.extra_pairs(12) == 4 and w.bullet_damage(12) > w.damage, "weapon extra pairs/damage")
	var laser := load("res://data/weapons/blue_laser.tres") as WeaponData
	_check(laser.laser_hit_damage(10) > laser.laser_hit_damage(3), "laser keeps growing")
	_check(MissileLauncher.shots_for(GameManager.missile_level) == 12 and MissileLauncher.damage_for(12) == 9, "missiles 12 shots, dmg 9")
	print("[hp] %s" % ("PASS" if _fails == 0 else "FAIL %d" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
