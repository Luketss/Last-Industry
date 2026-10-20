extends "res://tests/test_base.gd"
## Phase 8: achievements, key bindings and the offline Steam fallback.

const Achievements = preload("res://src/platform/achievements.gd")
const SteamService = preload("res://src/platform/steam_service.gd")
const Settings = preload("res://src/ui/settings.gd")
const Bindings = preload("res://src/ui/bindings.gd")


func _isolate() -> void:
	Achievements.path = "user://test_achievements.cfg"
	Settings.path = "user://test_settings.cfg"
	DirAccess.remove_absolute(Achievements.path)
	DirAccess.remove_absolute(Settings.path)
	Settings.load_all()
	Bindings.reload()


func _cleanup() -> void:
	DirAccess.remove_absolute(Achievements.path)
	DirAccess.remove_absolute(Settings.path)
	Achievements.path = "user://achievements.cfg"
	Settings.path = Settings.PATH
	Settings.load_all()
	Bindings.reload()


func test_achievements_unlock_once_and_persist() -> void:
	_isolate()
	var w = empty_world()
	var a = Achievements.new(data().achievements)
	eq(a.check(w.stats).size(), 0, "nada desbloqueado no início")
	w.stats.waves = 1
	var fresh: Array = a.check(w.stats)
	check(fresh.size() == 1 and fresh[0].id == "FIRST_NIGHT", "primeira noite desbloqueada")
	eq(a.check(w.stats).size(), 0, "não desbloqueia duas vezes")
	var b = Achievements.new(data().achievements)
	check(b.unlocked.has("FIRST_NIGHT"), "persistido entre sessões")
	_cleanup()


func test_flawless_and_elite_stats() -> void:
	var w = empty_world({"waves": {"first_delay": 1.0, "interval": 1.0e9, "spawn_gap": 0.1,
		"waves": [{"groups": [{"type": "crawler", "count": 1, "elite": true, "hp_mult": 2.0}]}]}})
	var t: int = w.place("turret_gun", Vector2i(10, 15), 0)
	w.buildings[t].inv = {"ammo": 8}
	run_seconds(w, 20.0)
	eq(w.stats.elite_kills, 1, "elite abatido contado")
	eq(w.stats.flawless, 1, "horda sem perdas contada")
	check(w.stats.peak_power >= 80, "pico de energia registrado")


func test_bindings_rebind_swaps_conflicts() -> void:
	_isolate()
	eq(Bindings.key("rotate"), KEY_R, "padrão")
	Bindings.rebind("rotate", KEY_Q)
	eq(Bindings.key("rotate"), KEY_Q, "nova tecla")
	eq(Bindings.key("pipette"), KEY_R, "conflito trocado")
	Bindings.reload()
	eq(Bindings.key("rotate"), KEY_Q, "persistido")
	var e := InputEventKey.new()
	e.keycode = KEY_Q
	eq(Bindings.action_for(e), "rotate", "evento mapeado")
	e.ctrl_pressed = true
	eq(Bindings.action_for(e), "", "Ctrl+tecla não dispara ações")
	Bindings.reset()
	eq(Bindings.key("rotate"), KEY_R, "restaurado")
	_cleanup()


func test_steam_offline_fallback() -> void:
	var s = SteamService.new()
	s._ready()
	check(not s.available, "sem GodotSteam o jogo fica offline")
	s.unlock("FIRST_NIGHT")
	s.set_presence("teste")
	eq(s.player_name(), "", "chamadas seguras sem Steam")
	s.free()


func test_every_achievement_stat_is_known() -> void:
	var w = empty_world()
	var known := ["produced", "consumed", "delivered", "built", "kills", "burned", "loaded", "waves",
		"researched", "tech", "ending", "terminals", "elite_kills", "flawless", "peak_power", "structures"]
	for d in data().achievements:
		check(str(d.stat).split(":")[0] in known, "estatística conhecida: %s" % d.stat)
		check(str(d.id) == str(d.id).to_upper(), "id no formato da Steam: %s" % d.id)
