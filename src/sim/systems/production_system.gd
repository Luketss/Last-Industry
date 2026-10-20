extends RefCounted
## Miners and crafting machines (smelters, assemblers).

const Defs = preload("res://src/sim/defs.gd")
const Items = preload("res://src/sim/items.gd")
const I18n = preload("res://src/ui/i18n.gd")


func request(w) -> void:
	for b in w.list("miner"):
		b.power_req = float(b.def.power) if _miner_can_work(w, b) else 0.0
	for b in w.list("crafter"):
		var r = w.data.recipes.get(b.recipe)
		var can: bool = b.enabled and r != null and (b.crafting or Items.has_all(b.inv, r.inputs)) and not _out_full(b)
		b.power_req = float(b.def.power) if can else 0.0


func _miner_can_work(w, b) -> bool:
	return b.enabled and Items.total(b.out) < int(b.def.get("buffer", 4)) and _remaining(w, b) > 0


static func _remaining(w, b) -> int:
	var n := 0
	for i in b.ore_cells:
		n += w.ore[i]
	return n


static func _out_full(b) -> bool:
	return Items.total(b.out) >= int(b.def.get("out_cap", 10))


func step(w, dt: float) -> void:
	for b in w.list("miner"):
		_step_miner(w, b, dt)
	for b in w.list("crafter"):
		_step_crafter(w, b, dt)


func _step_miner(w, b, dt: float) -> void:
	if not b.enabled:
		b.status = "desligado"
		return
	if _remaining(w, b) <= 0:
		b.status = "esgotado"
		w.add_alert("depleted%d" % b.id, I18n.t("Depósito esgotado sob uma Mineradora"), "warn", b.center(), 60.0)
		return
	if Items.total(b.out) >= int(b.def.get("buffer", 4)):
		b.status = "saída bloqueada"
		return
	if b.power_sat <= 0.0:
		b.status = "sem energia"
		return
	b.status = "minerando" if b.power_sat > 0.9 else "energia baixa"
	b.progress += float(b.def.rate) * (1.0 + w.research.mod("miner_rate")) * b.power_sat * dt
	if b.progress >= 1.0:
		b.progress -= 1.0
		for k in b.ore_cells.size():
			var i: int = b.ore_cells[(b.rr + k) % b.ore_cells.size()]
			if w.ore[i] > 0:
				w.ore[i] -= 1
				if w.ore[i] == 0:
					w.ore_version += 1
				var item: String = Defs.ORE_ITEM[w.terrain[i]]
				Items.add(b.out, item, 1)
				w.stats.on_produced(item, 1)
				b.rr = (b.rr + k + 1) % b.ore_cells.size()
				break


func _step_crafter(w, b, dt: float) -> void:
	if not b.enabled:
		b.status = "desligado"
		return
	var r = w.data.recipes.get(b.recipe)
	if r == null:
		b.status = "ociosa"
		return
	if not b.crafting:
		if _out_full(b):
			b.status = "saída bloqueada"
			return
		if not Items.has_all(b.inv, r.inputs):
			b.status = "sem insumos"
			return
		for k in r.inputs:
			Items.take(b.inv, k, int(r.inputs[k]))
			w.stats.on_consumed(k, int(r.inputs[k]))
		b.crafting = true
		b.progress = 0.0
	if b.power_sat <= 0.0:
		b.status = "sem energia"
		return
	b.status = "trabalhando" if b.power_sat > 0.9 else "energia baixa"
	b.progress += dt * b.power_sat * (1.0 + w.research.mod("crafter_speed")) / float(r.time)
	if b.progress >= 1.0:
		b.progress = 0.0
		b.crafting = false
		for k in r.outputs:
			Items.add(b.out, k, int(r.outputs[k]))
			w.stats.on_produced(k, int(r.outputs[k]))
