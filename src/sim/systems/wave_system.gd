extends RefCounted
## Announced invasions plus unannounced patrols. Waves are defined in data/waves.json;
## after the campaign, survival mode generates ever larger hordes.

const Defs = preload("res://src/sim/defs.gd")

var cfg: Dictionary
var index := 0               ## waves started so far
var timer := 0.0             ## seconds until the next wave
var next_spawn := 0          ## spawn point index announced for the next wave
var queue: Array = []        ## pending spawns [{type, spawn, mods}]
var spawn_timer := 0.0
var active := false
var patrol_timer := -1.0
var night := 0.0
var _warned := {}


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func setup(w) -> void:
	timer = float(cfg.get("first_delay", 300))
	next_spawn = _pick_spawn(w, -1)


func campaign_length() -> int:
	return cfg.get("waves", []).size()


func _pick_spawn(w, avoid: int) -> int:
	var n: int = w.spawn_points.size()
	if n == 0:
		return 0
	var s: int = w.rng.randi_range(0, n - 1)
	if s == avoid and n > 1:
		s = (s + 1) % n
	return s


func has_more(w) -> bool:
	return w.survival or index < campaign_length()


func wave_def(n: int) -> Dictionary:
	var list: Array = cfg.get("waves", [])
	if n < list.size():
		return list[n]
	var s: Dictionary = cfg.get("survival", {})
	var k := n - list.size() + 1
	var g := 1.0 + float(s.get("growth", 0.15)) * k
	return {"groups": [
		{"type": "crawler", "count": int(float(s.get("base_crawler", 20)) * g)},
		{"type": "runner", "count": int(float(s.get("base_runner", 10)) * g), "spawn": "other"},
		{"type": "brute", "count": int(float(s.get("base_brute", 3)) * g)},
		{"type": "glider", "count": int(float(s.get("base_glider", 8)) * g)},
		{"type": "saboteur", "count": int(float(s.get("base_saboteur", 5)) * g), "spawn": "other"},
		{"type": "brute", "count": 1, "elite": true, "hp_mult": 4.0 + k, "size_mult": 1.6, "damage_mult": 2.0, "spawn": "other"},
	]}


## Human readable preview of the next wave (for the HUD).
func describe_next(w) -> String:
	if not has_more(w):
		return ""
	var wd := wave_def(index)
	var parts := []
	for g in wd.groups:
		var nm: String = w.data.enemies[g.type].name
		parts.append("%d %s%s" % [int(g.count), nm, " (ELITE)" if g.get("elite", false) else ""])
	var dir := "?"
	if not w.spawn_points.is_empty():
		dir = Defs.compass(Vector2(w.spawn_points[next_spawn]), w.width, w.height)
	return "%s — vindo do %s" % [", ".join(parts), dir]


func step(w, dt: float) -> void:
	if has_more(w):
		timer -= dt
		for mark in [60, 30, 10]:
			var key := "%d_%d" % [index, mark]
			if timer <= mark and not _warned.has(key):
				_warned[key] = true
				w.add_alert("wave_warn", "Horda %d em %ds: %s" % [index + 1, mark, describe_next(w)], "danger" if mark <= 10 else "warn", null, 1.0)
				if mark == 60:
					w.trigger_lore("wave_warn:%d" % (index + 1))
		if timer <= 0.0:
			start_wave(w)
	if not queue.is_empty():
		spawn_timer -= dt
		while spawn_timer <= 0.0 and not queue.is_empty():
			var q: Dictionary = queue.pop_front()
			_spawn_at(w, q.type, int(q.spawn), q.mods)
			spawn_timer += float(cfg.get("spawn_gap", 0.35))
	if patrol_timer > 0.0:
		patrol_timer -= dt
		if patrol_timer <= 0.0:
			_patrol(w)
	if active and queue.is_empty() and w.enemies.is_empty():
		active = false
		w.stats.waves = index
		if w.stats.lost == w.stats.lost_at_wave_start:
			w.stats.flawless += 1
		w.events.append({"e": "wave_cleared", "n": index})
		w.add_alert("wave_clear", "Horda %d repelida. Reconstrua e prepare-se." % index, "info", null, 1.0)
		w.trigger_lore("wave_cleared:%d" % index)
		if not w.survival and index >= campaign_length():
			w.win()
	var target := 1.0 if (active or (has_more(w) and timer < 20.0)) else 0.0
	night = move_toward(night, target, dt / 6.0)


func start_wave(w) -> void:
	var wd := wave_def(index)
	var main_spawn := next_spawn
	var other := _pick_spawn(w, main_spawn)
	for g in wd.groups:
		var sp := other if str(g.get("spawn", "")) == "other" else main_spawn
		var mods := {}
		for k in ["elite", "hp_mult", "size_mult", "damage_mult"]:
			if g.has(k):
				mods[k] = g[k]
		for i in int(g.count):
			queue.append({"type": g.type, "spawn": sp, "mods": mods})
	index += 1
	active = true
	w.stats.lost_at_wave_start = w.stats.lost
	spawn_timer = 0.0
	timer = float(cfg.get("interval", 200))
	next_spawn = _pick_spawn(w, main_spawn)
	if index >= 2:
		patrol_timer = timer * w.rng.randf_range(0.4, 0.65)
	w.events.append({"e": "wave_start", "n": index, "boss": wd.get("boss", false)})
	w.add_alert("wave_start", "HORDA %d INICIADA%s" % [index, " — CHEFE DETECTADO" if wd.get("boss", false) else ""], "danger", null, 1.0)
	w.trigger_lore("wave_start:%d" % index)


## Unannounced small group: dangerous areas are never fully safe.
func _patrol(w) -> void:
	var sp := _pick_spawn(w, -1)
	var n := 2 + mini(index, 6)
	for i in n:
		# The hordes adapt as the facility researches: saboteurs join the patrols.
		var t := "runner" if i % 3 == 2 else "crawler"
		if w.stats.researched >= 2 and i % 2 == 0:
			t = "saboteur"
		_spawn_at(w, t, sp, {})
	w.add_alert("patrol", "Movimento hostil inesperado detectado ao %s!" % Defs.compass(Vector2(w.spawn_points[sp]), w.width, w.height), "danger", null, 1.0)


func _spawn_at(w, type: String, sp: int, mods: Dictionary) -> void:
	if w.spawn_points.is_empty():
		return
	var base: Vector2 = Vector2(w.spawn_points[sp % w.spawn_points.size()]) + Vector2(0.5, 0.5)
	var p := base + Vector2(w.rng.randf_range(-1.5, 1.5), w.rng.randf_range(-1.5, 1.5))
	if w.terrain_at(Vector2i(floori(p.x), floori(p.y))) == Defs.T_ROCK or w.building_at(Vector2i(floori(p.x), floori(p.y))) != null:
		p = base
	w.spawn_enemy(type, p, mods)


func to_dict() -> Dictionary:
	return {"index": index, "timer": timer, "next": next_spawn, "queue": queue, "st": spawn_timer,
		"active": active, "patrol": patrol_timer, "night": night, "warned": _warned.keys()}


func load_dict(d: Dictionary) -> void:
	index = int(d.index)
	timer = float(d.timer)
	next_spawn = int(d.next)
	queue = []
	for q in d.queue:
		queue.append({"type": str(q.type), "spawn": int(q.spawn), "mods": q.mods})
	spawn_timer = float(d.st)
	active = bool(d.active)
	patrol_timer = float(d.patrol)
	night = float(d.night)
	_warned = {}
	for k in d.get("warned", []):
		_warned[str(k)] = true
