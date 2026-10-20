extends RefCounted
## Electrical networks.
##
## Rules (shown to the player in the help screen):
## - Nodes (poles and the core) link to each other when within wire range of BOTH.
## - A structure is connected when any of its tiles lies inside a node's supply area.
## - Each connected group of nodes is an independent network (a sector).
## - When demand exceeds supply, priority 0 (defenses, repair) is served before
##   priority 1 (production). Batteries cover deficits and absorb surplus.
## - Generators burn fuel proportionally to the load they actually serve.

const Items = preload("res://src/sim/items.gd")

var dirty := true
var version := 0
var networks: Array = []
var links: Array = []      ## [[node_id_a, node_id_b]]
var totals := {}


func rebuild(w) -> void:
	dirty = false
	version += 1
	networks.clear()
	links.clear()
	var nodes := []
	for b in w.buildings.values():
		b.power_net = -1
		if b.def.has("supply_radius"):
			nodes.append(b)
	var parent := []
	for i in nodes.size():
		parent.append(i)
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var a = nodes[i]
			var c = nodes[j]
			var reach := minf(float(a.def.get("wire_range", 0.0)), float(c.def.get("wire_range", 0.0)))
			if a.center().distance_to(c.center()) <= reach:
				links.append([a.id, c.id])
				var ra := _find(parent, i)
				var rc := _find(parent, j)
				if ra != rc:
					parent[maxi(ra, rc)] = mini(ra, rc)
	var root_to_net := {}
	for i in nodes.size():
		var r := _find(parent, i)
		if not root_to_net.has(r):
			root_to_net[r] = networks.size()
			networks.append({"id": networks.size(), "members": [], "nodes": []})
		var n: int = root_to_net[r]
		nodes[i].power_net = n
		networks[n].members.append(nodes[i])
		networks[n].nodes.append(nodes[i])
	for b in w.buildings.values():
		if b.power_net != -1 or not uses_power(b):
			continue
		for n in nodes:
			if covers(n, b):
				b.power_net = n.power_net
				networks[b.power_net].members.append(b)
				break


static func uses_power(b) -> bool:
	return float(b.def.get("power", 0)) > 0.0 or b.def.has("power_out") or b.def.has("battery_capacity")


## Whether node `n`'s supply square overlaps building `b`'s footprint.
static func covers(n, b) -> bool:
	return covers_rect(n.center(), float(n.def.get("supply_radius", 0.0)), b.pos, b.size)


static func covers_rect(nc: Vector2, r: float, p: Vector2i, s: Vector2i) -> bool:
	return p.x < nc.x + r and p.x + s.x > nc.x - r and p.y < nc.y + r and p.y + s.y > nc.y - r


static func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func step(w, dt: float) -> void:
	var t := {"cap": 0.0, "demand": 0.0, "used": 0.0, "stored": 0.0, "capacity": 0.0, "sat": 1.0, "nets": networks.size()}
	for b in w.buildings.values():
		if b.power_net == -1:
			b.power_sat = 0.0
	for net in networks:
		var cap_free := 0.0
		var cap_gen := 0.0
		var gens := []
		var bats := []
		var demand := [0.0, 0.0]
		for b in net.members:
			if b.def.has("power_out"):
				var po := float(b.def.power_out)
				if str(b.def.get("fuel", "")) == "":
					cap_free += po
				else:
					if b.energy <= 0.0:
						_refuel(w, b)
					if b.energy > 0.0 and b.enabled:
						cap_gen += po
						gens.append(b)
					else:
						b.status = "sem combustível" if b.enabled else "desligado"
			if b.def.has("battery_capacity"):
				bats.append(b)
			if b.power_req > 0.0:
				demand[clampi(int(b.def.get("priority", 1)), 0, 1)] += b.power_req
		var bat_stored := 0.0
		var bat_cap := 0.0
		var bat_rate := 0.0
		for b in bats:
			bat_stored += b.energy
			bat_cap += float(b.def.battery_capacity)
			bat_rate += float(b.def.battery_rate)
		var bat_out_max := minf(bat_rate, bat_stored / dt)
		var supply := cap_free + cap_gen + bat_out_max
		var sat := [1.0, 1.0]
		var used := 0.0
		for p in 2:
			if demand[p] > 0.0:
				var s := minf(demand[p], supply)
				sat[p] = s / demand[p]
				supply -= s
				used += s
		var from_free := minf(used, cap_free)
		var from_gen := minf(used - from_free, cap_gen)
		var from_bat := maxf(used - from_free - from_gen, 0.0)
		var spare_free := cap_free - from_free
		var spare_gen := cap_gen - from_gen
		var charge := 0.0
		if bat_cap > 0.0:
			charge = minf(minf(spare_free + spare_gen, bat_rate), maxf(bat_cap - bat_stored, 0.0) / dt)
		var gen_load := from_gen + maxf(charge - spare_free, 0.0)
		for g in gens:
			var share := float(g.def.power_out) / cap_gen
			g.energy -= gen_load * share * dt
			g.status = "gerando" if gen_load > 0.0 else "ociosa"
			g.power_sat = gen_load / cap_gen
		if bat_cap > 0.0:
			var delta := (charge - from_bat) * dt
			for b in bats:
				var bc := float(b.def.battery_capacity)
				b.energy = clampf(b.energy + delta * bc / bat_cap, 0.0, bc)
				b.status = "carregando" if delta > 0.0 else ("ok" if b.energy > 0.0 else "ociosa")
		var any_supply := cap_free + cap_gen + bat_stored > 0.0
		for b in net.members:
			if b.def.has("power_out") and str(b.def.get("fuel", "")) != "":
				continue
			if b.power_req > 0.0:
				b.power_sat = sat[clampi(int(b.def.get("priority", 1)), 0, 1)]
			else:
				b.power_sat = 1.0 if any_supply else 0.0
		net["cap"] = cap_free + cap_gen
		net["demand"] = demand[0] + demand[1]
		net["used"] = used
		net["stored"] = bat_stored
		net["capacity"] = bat_cap
		net["sat"] = minf(sat[0], sat[1])
		t.cap += cap_free + cap_gen
		t.demand += demand[0] + demand[1]
		t.used += used
		t.stored += bat_stored
		t.capacity += bat_cap
		t.sat = minf(t.sat, net.sat)
	totals = t
	if t.sat < 0.98 and t.demand > 0.0:
		w.add_alert("power_low", "Energia insuficiente: %d%% da demanda atendida" % int(t.sat * 100.0), "warn", null, 15.0)


func _refuel(w, b) -> void:
	var fuel := str(b.def.fuel)
	if Items.take(b.inv, fuel, 1):
		b.energy += float(b.def.fuel_value)
		w.stats.on_consumed(fuel, 1)
		w.stats.burned += 1


func net_of(b) -> Dictionary:
	if b == null or b.power_net < 0 or b.power_net >= networks.size():
		return {}
	return networks[b.power_net]
