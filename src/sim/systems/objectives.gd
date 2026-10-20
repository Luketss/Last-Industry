extends RefCounted
## Guided campaign objectives, evaluated against Stats. Completing one may grant a reward
## and trigger a narrative transmission ("objective:<id>").

const Items = preload("res://src/sim/items.gd")
const Defs = preload("res://src/sim/defs.gd")
const I18n = preload("res://src/ui/i18n.gd")

var list: Array
var current := 0
var _timer := 0.0


func _init(p_list: Array) -> void:
	list = p_list


func current_objective():
	return list[current] if current < list.size() else null


## [current value, target] for the active objective.
func progress(w) -> Array:
	var o = current_objective()
	return [0, 0] if o == null else [mini(w.stats.value(str(o.stat)), int(o.n)), int(o.n)]


## Where on the map the active objective is done (shown as a marker), from its
## "point" field: "ore:iron" / "ore:coal" (nearest deposit to the core),
## "kind:<structure>" (nearest such structure), "nest:next" (next horde's nest)
## or "core". Null when there is nothing to point at.
func target(w):
	var o = current_objective()
	if o == null or not o.has("point") or w.core() == null:
		return null
	var p := str(o.point).split(":")
	var from: Vector2 = w.core().center()
	match p[0]:
		"core":
			return from
		"nest":
			if w.spawn_points.is_empty() or not w.waves.has_more(w):
				return null
			return Vector2(w.spawn_points[w.waves.next_spawn]) + Vector2(0.5, 0.5)
		"ore":
			var t := Defs.T_IRON if p[1] == "iron" else Defs.T_COAL
			var best = null
			var bd := INF
			for i in w.terrain.size():
				if w.terrain[i] == t and w.ore[i] > 0:
					var c := Vector2(i % w.width, i / w.width) + Vector2(0.5, 0.5)
					var d := c.distance_squared_to(from)
					if d < bd:
						bd = d
						best = c
			return best
		"kind":
			var best = null
			var bd := INF
			for b in w.buildings.values():
				if b.type == p[1] or b.kind == p[1]:
					var d: float = b.center().distance_squared_to(from)
					if d < bd:
						bd = d
						best = b.center()
			return best
	return null


func step(w, dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 0.5
	while current < list.size():
		var o: Dictionary = list[current]
		if w.stats.value(str(o.stat)) < int(o.n):
			break
		current += 1
		var reward: Dictionary = o.get("reward", {})
		for k in reward:
			Items.add(w.storage, k, int(reward[k]))
		w.events.append({"e": "objective", "id": o.id, "text": o.text})
		w.add_alert("obj", I18n.t("Objetivo concluído: %s") % o.text, "info", null, 0.0)
		w.trigger_lore("objective:%s" % o.id)


func to_dict() -> Dictionary:
	return {"current": current}


func load_dict(d: Dictionary) -> void:
	current = int(d.get("current", 0))
