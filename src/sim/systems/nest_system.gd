extends RefCounted
## Destructible nests. Every spawn point has integrity; turrets in range shoot
## the nest when they have no creature to aim at. A wounded nest regrows slowly
## and sends defenders out; a destroyed nest stops producing hordes for good and
## leaves salvage behind. With every nest gone the waves have nowhere to come from.

const I18n = preload("res://src/ui/i18n.gd")

const REGEN := 4.0             ## integrity per second while not under attack
const CALM_AFTER := 8.0        ## seconds without damage before regrowth starts
const DEFEND_EVERY := 9.0
const REWARD := {"iron_plate": 100, "gear": 60}

var hp: Array = []             ## parallel to World.spawn_points
var max_hp := 2500.0
var _last_hit: Array = []
var _defend: Array = []


func setup(w) -> void:
	max_hp = float(w.data.game.get("nest_hp", 2500))
	hp = []
	_last_hit = []
	_defend = []
	for i in w.spawn_points.size():
		hp.append(max_hp)
		_last_hit.append(-100.0)
		_defend.append(0.0)


func step(w, dt: float) -> void:
	for i in hp.size():
		if hp[i] >= max_hp:
			continue
		if w.time - _last_hit[i] > CALM_AFTER:
			hp[i] = minf(hp[i] + REGEN * dt, max_hp)
			continue
		_defend[i] -= dt
		if _defend[i] <= 0.0:
			_defend[i] = DEFEND_EVERY
			for k in 2:
				w.waves._spawn_at(w, "crawler" if k == 0 else "runner", i, {})


## Index of the nearest nest whose centre lies within `r` of `p`, or -1.
func nearest(w, p: Vector2, r: float) -> int:
	var best := -1
	var bd := r * r
	for i in w.spawn_points.size():
		var d: float = (Vector2(w.spawn_points[i]) + Vector2(0.5, 0.5)).distance_squared_to(p)
		if d <= bd:
			bd = d
			best = i
	return best


func damage(w, i: int, amount: float) -> void:
	if i < 0 or i >= hp.size():
		return
	hp[i] -= amount
	_last_hit[i] = w.time
	if hp[i] > 0.0:
		return
	var at := Vector2(w.spawn_points[i]) + Vector2(0.5, 0.5)
	w.spawn_points.remove_at(i)
	hp.remove_at(i)
	_last_hit.remove_at(i)
	_defend.remove_at(i)
	w.waves.on_nest_removed(w, i)
	for k in REWARD:
		w.storage[k] = int(w.storage.get(k, 0)) + int(REWARD[k])
	w.stats.nests += 1
	w.trigger_lore("nest:%d" % w.stats.nests)
	w.add_alert("nest_destroyed", I18n.t("Ninho destruído! As hordas não sairão mais dali."), "info", at, 0.0)
	w.events.append({"e": "nest_destroyed", "pos": at})


func to_dict() -> Dictionary:
	return {"hp": hp, "hit": _last_hit, "def": _defend}


func load_dict(w, d: Dictionary) -> void:
	setup(w)
	var h: Array = d.get("hp", [])
	if h.size() == hp.size():
		hp = h.duplicate()
		_last_hit = Array(d.get("hit", _last_hit)).duplicate()
		_defend = Array(d.get("def", _defend)).duplicate()
