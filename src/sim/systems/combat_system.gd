extends RefCounted
## Turrets (ballistic and electric), repair stations and drone hubs. A drone hub
## is a repair station with a long reach that takes its plates from the Core.

const Items = preload("res://src/sim/items.gd")
const I18n = preload("res://src/ui/i18n.gd")


func request(w) -> void:
	for b in w.list("turret_gun"):
		b.power_req = float(b.def.power) if b.enabled else 0.0
	for b in w.list("turret_tesla"):
		b.power_req = float(b.def.power) if b.enabled and b.energy < float(b.def.shot_cost) else 0.0
	for b in w.list("supply_hub"):
		b.power_req = float(b.def.power) if b.enabled else 0.0
	for b in w.list("repair"):
		var stock: Dictionary = w.storage if b.def.get("from_storage", false) else b.inv
		var has_mat: bool = b.energy > 0.0 or Items.count(stock, str(b.def.item)) > 0
		b.power_req = float(b.def.power) if b.enabled and b.target != 0 and has_mat else 0.0


func step(w, dt: float) -> void:
	for b in w.list("turret_gun"):
		_step_gun(w, b, dt)
	for b in w.list("turret_tesla"):
		_step_tesla(w, b, dt)
	for b in w.list("repair"):
		_step_repair(w, b, dt)
	for b in w.list("supply_hub"):
		_step_supply(w, b, dt)


## Supply hub: drones carry ammo, shells, plates and coal from the Core's stock to
## the turrets, repair stations and generators in range that are running low.
const SUPPLY_KINDS := ["turret_gun", "repair", "generator"]


func _step_supply(w, b, dt: float) -> void:
	if not b.enabled:
		b.status = "desligado"
		return
	if b.power_sat < 0.5:
		b.status = "sem energia"
		return
	b.scan -= dt
	if b.scan > 0.0:
		return
	b.scan = float(b.def.interval)
	var best = null
	var best_item := ""
	var best_fill := 0.75   # only top up below 75%
	var c: Vector2 = b.center()
	for o in w.buildings.values():
		if not (o.kind in SUPPLY_KINDS) or o.def.get("from_storage", false) or c.distance_to(o.center()) > float(b.def.radius):
			continue
		var acc: Dictionary = o.def.get("accepts", {})
		for item in acc:
			if Items.count(w.storage, item) <= 0:
				continue
			var fill := float(Items.count(o.inv, item)) / float(acc[item])
			if fill < best_fill:
				best_fill = fill
				best = o
				best_item = item
	if best == null:
		b.status = "ocioso"
		return
	var n := mini(int(b.def.get("carry", 2)), mini(Items.count(w.storage, best_item), int(best.def.accepts[best_item]) - Items.count(best.inv, best_item)))
	Items.take(w.storage, best_item, n)
	Items.add(best.inv, best_item, n)
	b.status = "abastecendo"
	w.events.append({"e": "drone", "from": c, "to": best.center(), "supply": true})


func _step_gun(w, b, dt: float) -> void:
	if not b.enabled:
		b.status = "desligado"
		return
	var item := str(b.def.ammo_item)
	if b.rounds <= 0 and Items.take(b.inv, item, 1):
		b.rounds += int(b.def.rounds_per_item)
		w.stats.on_consumed(item, 1)
		w.stats.loaded += 1
	var rate := 1.0 if b.power_sat >= 0.99 else lerpf(0.3, 1.0, b.power_sat)
	b.cooldown = maxf(b.cooldown - dt * rate, 0.0)
	if b.rounds <= 0:
		b.status = "sem munição"
		w.add_alert("no_ammo", I18n.t("Torre Balística sem munição"), "danger" if not w.enemies.is_empty() else "warn", b.center(), 12.0)
		return
	var e = _acquire(w, b, dt)
	if e == null:
		# Nothing to shoot at: ground turrets wear down a nest in range.
		var n: int = -1 if str(b.def.get("targets", "ground")) == "air" else w.nests.nearest(w, b.center(), float(b.def.range))
		if n == -1:
			b.status = "vigiando"
			return
		var np := Vector2(w.spawn_points[n]) + Vector2(0.5, 0.5)
		b.aim = atan2(np.y - b.center().y, np.x - b.center().x)
		b.status = "atacando"
		if b.cooldown <= 0.0:
			b.cooldown = float(b.def.cooldown)
			b.rounds -= 1
			w.stats.shots += 1
			var kind := "shell" if float(b.def.get("splash", 0.0)) > 0.0 else "shot"
			w.events.append({"e": kind, "id": b.id, "from": b.center(), "to": np, "r": float(b.def.get("splash", 0.0))})
			w.nests.damage(w, n, float(b.def.damage) * (1.0 + w.research.mod("turret_damage")))
		return
	b.status = "atacando" if b.power_sat > 0.5 else "energia baixa"
	if b.cooldown <= 0.0:
		b.cooldown = float(b.def.cooldown)
		b.rounds -= 1
		w.stats.shots += 1
		var to: Vector2 = e.pos
		var dmg: float = float(b.def.damage) * (1.0 + w.research.mod("turret_damage"))
		var splash := float(b.def.get("splash", 0.0))
		if splash > 0.0:
			for o in w.enemies.values():
				if not o.dead and not o.def.get("flying", false) and o.pos.distance_to(to) <= splash:
					w.damage_enemy(o, dmg * (1.0 if o == e else 0.6))
			w.events.append({"e": "shell", "id": b.id, "from": b.center(), "to": to, "r": splash})
		else:
			w.damage_enemy(e, dmg)
			w.events.append({"e": "shot", "id": b.id, "from": b.center(), "to": to, "air": e.def.get("flying", false)})


func _step_tesla(w, b, dt: float) -> void:
	if not b.enabled:
		b.status = "desligado"
		return
	var cost := float(b.def.shot_cost)
	if b.power_req > 0.0:
		b.energy = minf(b.energy + b.power_req * b.power_sat * dt, cost)
	b.cooldown = maxf(b.cooldown - dt, 0.0)
	if b.energy < cost:
		b.status = "sem energia" if b.power_sat <= 0.0 else "carregando"
		return
	var e = _acquire(w, b, dt)
	if e == null:
		b.status = "pronta"
		return
	b.status = "atacando"
	if b.cooldown > 0.0:
		return
	b.cooldown = float(b.def.cooldown)
	b.energy -= cost
	var pts := [b.center()]
	var hit := {}
	var cur = e
	for i in int(b.def.chain):
		hit[cur.id] = true
		pts.append(cur.pos)
		w.damage_enemy(cur, float(b.def.damage) * (1.0 if i == 0 else 0.7))
		cur = _nearest_enemy(w, cur.pos, float(b.def.chain_range), hit, "both")
		if cur == null:
			break
	w.events.append({"e": "arc", "id": b.id, "points": pts})


func _acquire(w, b, dt: float):
	var rng := float(b.def.range)
	var c: Vector2 = b.center()
	var e = w.enemies.get(b.target) if b.target != 0 else null
	if e != null and not e.dead and c.distance_to(e.pos) <= rng:
		b.aim = atan2(e.pos.y - c.y, e.pos.x - c.x)
		return e
	b.target = 0
	b.scan -= dt
	if b.scan > 0.0:
		return null
	b.scan = 0.2
	e = _nearest_enemy(w, c, rng, {}, str(b.def.get("targets", "ground")))
	if e != null:
		b.target = e.id
		b.aim = atan2(e.pos.y - c.y, e.pos.x - c.x)
	return e


## `targets`: "ground", "air" or "both".
static func _nearest_enemy(w, p: Vector2, radius: float, exclude: Dictionary, targets: String):
	var best = null
	var bd := radius * radius
	for e in w.enemies.values():
		if e.dead or exclude.has(e.id):
			continue
		var fly: bool = e.def.get("flying", false)
		if (fly and targets == "ground") or (not fly and targets == "air"):
			continue
		var d: float = p.distance_squared_to(e.pos)
		if d <= bd:
			bd = d
			best = e
	return best


func _step_repair(w, b, dt: float) -> void:
	if not b.enabled:
		b.status = "desligado"
		return
	b.scan -= dt
	if b.scan <= 0.0:
		b.scan = 1.0
		b.target = _most_damaged(w, b)
	var t = w.buildings.get(b.target) if b.target != 0 else null
	if t == null or t.hp >= t.max_hp:
		b.target = 0
		b.status = "ocioso"
		return
	if b.energy <= 0.0:
		var stock: Dictionary = w.storage if b.def.get("from_storage", false) else b.inv
		if Items.take(stock, str(b.def.item), 1):
			b.energy += float(b.def.heal_per_item)
			w.stats.on_consumed(str(b.def.item), 1)
		else:
			b.status = "sem materiais"
			return
	if b.power_sat <= 0.0:
		b.status = "sem energia"
		return
	var heal := minf(minf(float(b.def.heal_rate) * dt * b.power_sat, b.energy), t.max_hp - t.hp)
	t.hp += heal
	b.energy -= heal
	b.status = "reparando"
	if b.def.get("from_storage", false):
		if w.tick % 24 == b.id % 24:
			w.events.append({"e": "drone", "from": b.center(), "to": t.center()})
	elif w.tick % 10 == 0:
		w.events.append({"e": "repair", "from": b.center(), "to": t.center()})


static func _most_damaged(w, b) -> int:
	var r := float(b.def.radius)
	var c: Vector2 = b.center()
	var best := 0
	var br := 0.999
	for o in w.buildings.values():
		if o.hp >= o.max_hp:
			continue
		var ratio: float = o.hp / o.max_hp
		if ratio < br and c.distance_to(o.center()) <= r:
			br = ratio
			best = o.id
	return best
