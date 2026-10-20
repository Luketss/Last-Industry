extends RefCounted
## Guided campaign objectives, evaluated against Stats. Completing one may grant a reward
## and trigger a narrative transmission ("objective:<id>").

const Items = preload("res://src/sim/items.gd")
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
