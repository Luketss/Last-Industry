extends RefCounted
## Technology tree (data/research.json).
##
## Labs consume research packs (one at a time, `unit_time` seconds each at full
## power) toward the currently selected technology. Completing a technology applies
## its modifiers, unlocks buildings/recipes and may trigger narrative events.

const Items = preload("res://src/sim/items.gd")
const I18n = preload("res://src/ui/i18n.gd")

var techs := {}            ## id -> definition
var order: Array = []      ## ids in data order
var done := {}             ## id -> true
var current := ""
var remaining := {}        ## id -> {pack: count still needed}
var mods := {}             ## modifier -> accumulated bonus
var unlocked := {}         ## building/recipe id -> true
var unlocked_by := {}      ## building/recipe id -> tech id (for UI hints)


func _init(list: Array) -> void:
	for t in list:
		techs[t.id] = t
		order.append(t.id)
		for b in t.get("unlocks", []):
			unlocked_by[b] = t.id
		for r in t.get("unlocks_recipes", []):
			unlocked_by[r] = t.id


func mod(key: String) -> float:
	return float(mods.get(key, 0.0))


func is_available(id: String) -> bool:
	if not techs.has(id) or done.has(id):
		return false
	for r in techs[id].get("requires", []):
		if not done.has(r):
			return false
	return true


func remaining_of(id: String) -> Dictionary:
	if not remaining.has(id):
		remaining[id] = Items.from_json(techs[id].cost)
	return remaining[id]


## Fraction of the technology already researched (0..1).
func fraction(id: String) -> float:
	var total := 0
	for k in techs[id].cost:
		total += int(techs[id].cost[k])
	if total == 0 or done.has(id):
		return 1.0
	return 1.0 - float(Items.total(remaining_of(id))) / float(total)


func select(w, id: String) -> bool:
	if not is_available(id):
		return false
	current = id
	remaining_of(id)
	return true


func request(w) -> void:
	for b in w.list("lab"):
		b.power_req = float(b.def.power) if b.enabled and current != "" and (b.crafting or _next_pack(w, b) != "") else 0.0


func step(w, dt: float) -> void:
	for b in w.list("lab"):
		if not b.enabled:
			b.status = "desligado"
			continue
		if current == "":
			b.status = "sem pesquisa"
			continue
		if not b.crafting:
			var pack := _next_pack(w, b)
			if pack == "":
				b.status = "sem insumos"
				continue
			Items.take(b.inv, pack, 1)
			w.stats.on_consumed(pack, 1)
			b.recipe = pack
			b.crafting = true
			b.progress = 0.0
		if b.power_sat <= 0.0:
			b.status = "sem energia"
			continue
		b.status = "pesquisando" if b.power_sat > 0.9 else "energia baixa"
		b.progress += dt * b.power_sat / float(b.def.get("unit_time", 4.0))
		if b.progress >= 1.0:
			b.progress = 0.0
			b.crafting = false
			_contribute(w, b.recipe)


## A pack this lab holds that the current technology still needs, considering
## packs other labs are already processing.
func _next_pack(w, lab) -> String:
	if current == "":
		return ""
	var rem := remaining_of(current)
	for pack in rem:
		var need := int(rem[pack])
		for other in w.list("lab"):
			if other != lab and other.crafting and other.recipe == pack:
				need -= 1
		if need > 0 and Items.count(lab.inv, pack) > 0:
			return pack
	return ""


func _contribute(w, pack: String) -> void:
	if current == "":
		return
	var rem := remaining_of(current)
	if int(rem.get(pack, 0)) > 0:
		Items.take(rem, pack, 1)
	if rem.is_empty():
		complete(w, current)


func complete(w, id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	_apply(techs[id])
	if current == id:
		current = ""
	w.stats.researched += 1
	w.stats.techs[id] = 1
	w.on_research_complete(id)
	w.events.append({"e": "research", "id": id})
	w.add_alert("research", I18n.t("Pesquisa concluída: %s") % techs[id].name, "info", null, 0.0)
	w.trigger_lore("research:%s" % id)
	w.trigger_lore("research_count:%d" % done.size())


func _apply(t: Dictionary) -> void:
	for k in t.get("mods", {}):
		mods[k] = mod(k) + float(t.mods[k])
	for b in t.get("unlocks", []):
		unlocked[b] = true
	for r in t.get("unlocks_recipes", []):
		unlocked[r] = true


func to_dict() -> Dictionary:
	return {"done": done.keys(), "current": current, "remaining": remaining}


func load_dict(d: Dictionary) -> void:
	done = {}
	mods = {}
	unlocked = {}
	for id in d.get("done", []):
		if techs.has(id):
			done[id] = true
			_apply(techs[id])
	current = str(d.get("current", ""))
	remaining = {}
	var rd: Dictionary = d.get("remaining", {})
	for id in rd:
		remaining[str(id)] = Items.from_json(rd[id])
