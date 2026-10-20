extends RefCounted
## Authoritative, deterministic game simulation. Contains no rendering code:
## the view layer reads this state and consumes `events` every frame.
## Runs at a fixed tick (Defs.TICK_RATE) so it is reproducible and testable headless.

const Defs = preload("res://src/sim/defs.gd")
const Items = preload("res://src/sim/items.gd")
const Building = preload("res://src/sim/building.gd")
const Enemy = preload("res://src/sim/enemy.gd")
const MapGenerator = preload("res://src/sim/map_generator.gd")
const PowerSystem = preload("res://src/sim/systems/power_system.gd")
const LogisticsSystem = preload("res://src/sim/systems/logistics_system.gd")
const ProductionSystem = preload("res://src/sim/systems/production_system.gd")
const Pathfinding = preload("res://src/sim/systems/pathfinding.gd")
const EnemySystem = preload("res://src/sim/systems/enemy_system.gd")
const CombatSystem = preload("res://src/sim/systems/combat_system.gd")
const WaveSystem = preload("res://src/sim/systems/wave_system.gd")
const Stats = preload("res://src/sim/systems/stats.gd")
const Objectives = preload("res://src/sim/systems/objectives.gd")
const ResearchSystem = preload("res://src/sim/systems/research_system.gd")

const SAVE_VERSION := 1

var data
var width := 64
var height := 64
var map_seed := 1
var terrain := PackedByteArray()
var ore := PackedInt32Array()
var grid := PackedInt32Array()
var buildings := {}
var enemies := {}
var ghosts := {}            ## origin cell index -> {type, rot, recipe, x, y}
var storage := {}           ## the core's shared inventory, used for construction
var spawn_points: Array = []
var core_id := 0
var next_id := 1
var tick := 0
var time := 0.0
var rng := RandomNumberGenerator.new()
var state := "playing"      ## playing | won | lost
var survival := false

var events: Array = []      ## transient, consumed by view/UI each frame
var alerts: Array = []      ## newest first
var transmissions: Array = []
var _alert_times := {}
var _dead_enemies: Array = []

var structures_version := 0
var ghosts_version := 0
var ore_version := 0
var _lists := {}
var _lists_version := -1

var power: PowerSystem
var logistics: LogisticsSystem
var production: ProductionSystem
var pathing: Pathfinding
var enemy_sys: EnemySystem
var combat: CombatSystem
var waves: WaveSystem
var stats: Stats
var objectives: Objectives
var research: ResearchSystem


func _init(p_data, p_seed: int = 1, opts: Dictionary = {}) -> void:
	data = p_data
	map_seed = p_seed
	rng.seed = p_seed
	var map_cfg: Dictionary = data.game.get("map", {})
	width = int(opts.get("width", map_cfg.get("width", 64)))
	height = int(opts.get("height", map_cfg.get("height", 64)))
	terrain.resize(width * height)
	terrain.fill(Defs.T_GROUND)
	ore.resize(width * height)
	ore.fill(0)
	grid.resize(width * height)
	grid.fill(0)
	power = PowerSystem.new()
	logistics = LogisticsSystem.new()
	production = ProductionSystem.new()
	pathing = Pathfinding.new(data)
	enemy_sys = EnemySystem.new()
	combat = CombatSystem.new()
	waves = WaveSystem.new(data.waves)
	stats = Stats.new()
	objectives = Objectives.new(data.objectives)
	research = ResearchSystem.new(data.research)
	if not opts.get("load", false):
		storage = Items.from_json(opts.get("storage", data.game.get("start_storage", {})))
		if opts.get("generate", true):
			MapGenerator.generate(self, p_seed)
		if opts.get("core", true):
			var c := Vector2i(width / 2 - 1, height / 2 - 1)
			core_id = place("core", c, 0, true)
		if opts.has("spawns"):
			spawn_points = opts.spawns.duplicate()
		if opts.has("waves"):
			waves = WaveSystem.new(opts.waves)
		waves.setup(self)
		trigger_lore("start")


# --- grid helpers -----------------------------------------------------------

func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func building_at(c: Vector2i):
	if not in_bounds(c):
		return null
	var id := grid[idx(c)]
	if id == 0:
		return null
	return buildings.get(id)


func terrain_at(c: Vector2i) -> int:
	return terrain[idx(c)] if in_bounds(c) else Defs.T_ROCK


func set_terrain(c: Vector2i, t: int, amount: int = 0) -> void:
	terrain[idx(c)] = t
	ore[idx(c)] = amount


func list(kind: String) -> Array:
	if _lists_version != structures_version:
		_rebuild_lists()
	return _lists.get(kind, [])


func _rebuild_lists() -> void:
	_lists = {"pullers": [], "outputters": []}
	for b in buildings.values():
		if not _lists.has(b.kind):
			_lists[b.kind] = []
		_lists[b.kind].append(b)
		if b.def.get("pull", false):
			_lists.pullers.append(b)
		if b.kind in ["miner", "crafter", "depot", "splitter"]:
			_lists.outputters.append(b)
	_lists_version = structures_version


func core():
	return buildings.get(core_id)


# --- construction -----------------------------------------------------------

func is_unlocked(id: String) -> bool:
	var def = data.buildings.get(id, data.recipes.get(id))
	return def != null and (not def.get("locked", false) or research.unlocked.has(id))


func can_afford(cost: Dictionary) -> bool:
	return Items.has_all(storage, cost)


## Returns "" when placement is valid, otherwise a human readable reason.
func can_place(type: String, p: Vector2i, rot: int, check_cost: bool = true) -> String:
	var def = data.buildings.get(type)
	if def == null:
		return "Estrutura desconhecida"
	if not is_unlocked(type):
		var tech = research.techs.get(research.unlocked_by.get(type, ""))
		return "Requer pesquisa: %s" % (tech.name if tech != null else "?")
	var sz := Building.footprint(def, rot)
	var on_ore := false
	for y in sz.y:
		for x in sz.x:
			var c := p + Vector2i(x, y)
			if not in_bounds(c):
				return "Fora do mapa"
			var i := idx(c)
			if grid[i] != 0:
				return "Espaço ocupado"
			var t := terrain[i]
			if t == Defs.T_ROCK:
				return "Terreno bloqueado"
			if Defs.ORE_ITEM.has(t) and ore[i] > 0:
				on_ore = true
	if def.get("kind", "") == "miner" and not on_ore:
		return "Requer depósito de minério"
	var center := Vector2(p) + Vector2(sz) * 0.5
	for sp in spawn_points:
		if (Vector2(sp) + Vector2(0.5, 0.5)).distance_to(center) < 5.0:
			return "Muito perto de um ninho"
	if check_cost and not can_afford(def.get("cost", {})):
		return "Recursos insuficientes"
	return ""


func place(type: String, p: Vector2i, rot: int, free: bool = false, recipe: String = "") -> int:
	if can_place(type, p, rot, not free) != "":
		return 0
	var def: Dictionary = data.buildings[type]
	if not free:
		var cost: Dictionary = def.get("cost", {})
		for k in cost:
			Items.take(storage, k, int(cost[k]))
	var b := Building.new()
	b.setup(next_id, type, def, p, rot)
	next_id += 1
	if b.kind == "crafter" and not is_unlocked(b.recipe):
		b.recipe = ""
		for r in def.recipes:
			if is_unlocked(r):
				b.recipe = r
				break
	if recipe != "" and recipe in def.get("recipes", []) and is_unlocked(recipe):
		b.recipe = recipe
	_register(b)
	b.hp = b.max_hp
	_clear_ghosts_overlapping(b)
	stats.on_built(type)
	events.append({"e": "built", "id": b.id})
	return b.id


func _register(b) -> void:
	if b.kind == "wall":
		b.max_hp = float(b.def.hp) * (1.0 + research.mod("wall_hp"))
		b.hp = minf(b.hp, b.max_hp)
	buildings[b.id] = b
	for c in b.cells():
		grid[idx(c)] = b.id
	if b.kind == "miner":
		b.ore_cells = []
		for c in b.cells():
			if Defs.ORE_ITEM.has(terrain[idx(c)]):
				b.ore_cells.append(idx(c))
	_mark_structures()


func _unregister(b) -> void:
	for c in b.cells():
		if grid[idx(c)] == b.id:
			grid[idx(c)] = 0
	buildings.erase(b.id)
	_mark_structures()


func _mark_structures() -> void:
	structures_version += 1
	power.dirty = true
	logistics.dirty = true
	pathing.dirty = true


## Player demolition: refunds the full cost plus any carried items.
func remove(id: int) -> bool:
	var b = buildings.get(id)
	if b == null or b.kind == "core":
		return false
	var cost: Dictionary = b.def.get("cost", {})
	for k in cost:
		Items.add(storage, k, int(cost[k]))
	for k in b.inv:
		Items.add(storage, k, int(b.inv[k]))
	for k in b.out:
		Items.add(storage, k, int(b.out[k]))
	for it in b.belt_items:
		Items.add(storage, it[0], 1)
	_unregister(b)
	events.append({"e": "removed", "id": id})
	return true


func damage_building(b, amount: float) -> void:
	if b == null or b.hp <= 0.0:
		return
	b.hp -= amount
	b.last_damaged = time
	if b.kind == "core":
		add_alert("core_hit", "O NÚCLEO ESTÁ SOB ATAQUE!", "danger", b.center(), 6.0)
	else:
		add_alert("attack", "%s sob ataque" % b.def.name, "warn", b.center(), 6.0)
	if b.hp <= 0.0:
		destroy(b)


## Destruction by enemies: leaves a ghost so the player can rebuild it.
func destroy(b) -> void:
	_unregister(b)
	stats.lost += 1
	events.append({"e": "destroyed", "id": b.id, "pos": b.center(), "type": b.type})
	if b.kind == "core":
		state = "lost"
		events.append({"e": "lost"})
		return
	ghosts[idx(b.pos)] = {"type": b.type, "rot": b.rot, "recipe": b.recipe, "x": b.pos.x, "y": b.pos.y, "filter": b.filter.duplicate()}
	ghosts_version += 1
	add_alert("destroyed", "%s destruída! (G para reconstruir)" % b.def.name, "danger", b.center(), 3.0)


func _clear_ghosts_overlapping(b) -> void:
	var removed := false
	for key in ghosts.keys():
		var g: Dictionary = ghosts[key]
		var gs := Building.footprint(data.buildings[g.type], int(g.rot))
		var gp := Vector2i(int(g.x), int(g.y))
		if gp.x < b.pos.x + b.size.x and gp.x + gs.x > b.pos.x and gp.y < b.pos.y + b.size.y and gp.y + gs.y > b.pos.y:
			ghosts.erase(key)
			removed = true
	if removed:
		ghosts_version += 1


func rebuild_ghost(key: int) -> bool:
	var g = ghosts.get(key)
	if g == null:
		return false
	var id := place(g.type, Vector2i(int(g.x), int(g.y)), int(g.rot), false, str(g.recipe))
	if id != 0 and g.has("filter"):
		set_filters(buildings[id], g.filter)
	return id != 0


func rebuild_all_ghosts() -> int:
	var n := 0
	var keys := ghosts.keys()
	keys.sort()
	for key in keys:
		if ghosts.has(key) and rebuild_ghost(key):
			n += 1
	return n


func remove_ghost(key: int) -> void:
	if ghosts.erase(key):
		ghosts_version += 1


func ghost_at(c: Vector2i) -> int:
	for key in ghosts:
		var g: Dictionary = ghosts[key]
		var gs := Building.footprint(data.buildings[g.type], int(g.rot))
		if c.x >= int(g.x) and c.y >= int(g.y) and c.x < int(g.x) + gs.x and c.y < int(g.y) + gs.y:
			return key
	return -1


## Re-orients a square structure in place (its footprint is unchanged).
func rotate_building(b, r: int) -> void:
	if b == null or b.size.x != b.size.y or b.kind == "core" or b.rot == posmod(r, 4):
		return
	b.rot = posmod(r, 4)
	_mark_structures()
	events.append({"e": "built", "id": b.id})


func set_recipe(b, recipe: String) -> void:
	if b == null or b.kind != "crafter" or recipe == b.recipe or not (recipe in b.def.get("recipes", [])) or not is_unlocked(recipe):
		return
	# Return buffered inputs to storage so nothing is silently lost.
	for k in b.inv:
		Items.add(storage, k, int(b.inv[k]))
	b.inv = {}
	b.recipe = recipe
	b.crafting = false
	b.progress = 0.0


## Splitter routing: `slot` 0 left, 1 front, 2 right relative to its rotation;
## "" lets any item through. Items with a matching filter go only there; other
## items use the unfiltered outputs.
func set_filter(b, slot: int, item: String) -> void:
	if b == null or b.kind != "splitter" or slot < 0 or slot > 2:
		return
	if item != "" and not data.items.has(item):
		return
	b.filter[slot] = item


func set_filters(b, f: Array) -> void:
	for i in mini(f.size(), 3):
		set_filter(b, i, str(f[i]))


# --- items --------------------------------------------------------------------

## Offer one item to a non-belt building. Returns true when accepted.
func try_insert(b, item: String) -> bool:
	match b.kind:
		"core":
			Items.add(storage, item, 1)
			stats.on_delivered(item)
			return true
		"depot":
			if Items.total(b.inv) < int(b.def.get("capacity", 100)):
				Items.add(b.inv, item, 1)
				return true
		"crafter":
			if not b.enabled:
				return false
			var r = data.recipes.get(b.recipe)
			if r != null and r.inputs.has(item) and Items.count(b.inv, item) < int(r.inputs[item]) * 3:
				Items.add(b.inv, item, 1)
				return true
		"splitter":
			if Items.total(b.out) < 2:
				Items.add(b.out, item, 1)
				return true
		_:
			var acc: Dictionary = b.def.get("accepts", {})
			if acc.has(item) and Items.count(b.inv, item) < int(acc[item]):
				Items.add(b.inv, item, 1)
				return true
	return false


# --- enemies ------------------------------------------------------------------

func spawn_enemy(type: String, p: Vector2, mods: Dictionary = {}) -> int:
	var def = data.enemies.get(type)
	if def == null:
		return 0
	var e := Enemy.new()
	e.id = next_id
	next_id += 1
	e.type = type
	e.def = def
	e.pos = p
	e.hp_mult = float(mods.get("hp_mult", 1.0))
	e.size_mult = float(mods.get("size_mult", 1.0))
	e.damage_mult = float(mods.get("damage_mult", 1.0))
	e.elite = bool(mods.get("elite", false))
	e.max_hp = float(def.hp) * e.hp_mult
	e.hp = e.max_hp
	e.profile = pathing.profile_of(type)
	e.offset = _offset_for(e.id)
	enemies[e.id] = e
	return e.id


static func _offset_for(id: int) -> Vector2:
	var h := hash(id)
	return Vector2(((h & 255) / 255.0 - 0.5) * 0.5, (((h >> 8) & 255) / 255.0 - 0.5) * 0.5)


func damage_enemy(e, amount: float) -> void:
	if e == null or e.dead:
		return
	e.hp -= amount * (1.0 - float(e.def.get("armor", 0.0)))
	e.hit_time = time
	if e.hp <= 0.0:
		e.dead = true
		_dead_enemies.append(e)


func flush_dead() -> void:
	for e in _dead_enemies:
		if enemies.erase(e.id):
			stats.kills += 1
			if e.elite:
				stats.elite_kills += 1
			events.append({"e": "enemy_died", "pos": e.pos, "type": e.type, "elite": e.elite})
	_dead_enemies.clear()


# --- messages -----------------------------------------------------------------

func add_alert(key: String, text: String, level: String = "warn", p = null, cooldown: float = 8.0) -> void:
	if _alert_times.has(key) and time - float(_alert_times[key]) < cooldown:
		return
	_alert_times[key] = time
	alerts.push_front({"text": text, "level": level, "time": time, "pos": p})
	if alerts.size() > 7:
		alerts.resize(7)
	events.append({"e": "alert", "level": level, "text": text})


func trigger_lore(trigger: String) -> void:
	for entry in data.lore:
		if entry.trigger == trigger:
			transmissions.append({"title": entry.title, "text": entry.text, "time": time})
			events.append({"e": "transmission", "title": entry.title, "text": entry.text})


# --- tick -----------------------------------------------------------------------

func step() -> void:
	if state != "playing":
		return
	var dt := Defs.DT
	tick += 1
	time += dt
	if logistics.dirty:
		logistics.rebuild(self)
	if power.dirty:
		power.rebuild(self)
	production.request(self)
	combat.request(self)
	research.request(self)
	power.step(self, dt)
	production.step(self, dt)
	research.step(self, dt)
	logistics.step(self, dt)
	pathing.update(self, dt)
	enemy_sys.step(self, dt)
	combat.step(self, dt)
	flush_dead()
	if state != "playing":
		return
	waves.step(self, dt)
	stats.step(self, dt)
	objectives.step(self, dt)


## Applies research effects to structures that already exist.
func on_research_complete(_id: String) -> void:
	var full := 1.0 + research.mod("wall_hp")
	for b in list("wall"):
		var ratio: float = b.hp / b.max_hp
		b.max_hp = float(b.def.hp) * full
		b.hp = b.max_hp * ratio


## 1 at day, 0.1 at the darkest night (solar output).
func daylight() -> float:
	return 1.0 - 0.9 * waves.night


func win() -> void:
	if state == "playing" and not survival:
		state = "won"
		events.append({"e": "won"})
		trigger_lore("victory")


func continue_survival() -> void:
	survival = true
	state = "playing"
	waves.timer = float(waves.cfg.get("interval", 200))


## Called before serialising so a loaded game continues exactly like the original.
func flush_caches() -> void:
	if logistics.dirty:
		logistics.rebuild(self)
	if power.dirty:
		power.rebuild(self)
	if pathing.dirty:
		pathing.rebuild(self)


# --- persistence ----------------------------------------------------------------

func to_dict() -> Dictionary:
	flush_caches()
	var bl := []
	for b in buildings.values():
		bl.append(b.to_dict())
	var el := []
	for e in enemies.values():
		el.append(e.to_dict())
	var gl := []
	for key in ghosts:
		gl.append(ghosts[key])
	var sp := []
	for s in spawn_points:
		sp.append([s.x, s.y])
	return {
		"version": SAVE_VERSION, "seed": str(map_seed), "w": width, "h": height,
		"terrain": Marshalls.raw_to_base64(terrain),
		"ore": Marshalls.raw_to_base64(ore.to_byte_array()),
		"tick": tick, "time": time, "next_id": next_id, "core_id": core_id,
		"storage": storage, "state": state, "survival": survival, "rng": str(rng.state),
		"buildings": bl, "enemies": el, "ghosts": gl, "spawns": sp,
		"waves": waves.to_dict(), "stats": stats.to_dict(), "objectives": objectives.to_dict(),
		"research": research.to_dict(),
		"transmissions": transmissions, "pathing_cd": pathing.cooldown,
	}


static func from_dict(p_data, d: Dictionary):
	var w = load("res://src/sim/world.gd").new(p_data, int(str(d.get("seed", "1"))), {
		"load": true, "width": int(d.w), "height": int(d.h)})
	w.terrain = Marshalls.base64_to_raw(d.terrain)
	w.ore = Marshalls.base64_to_raw(d.ore).to_int32_array()
	w.tick = int(d.tick)
	w.time = float(d.time)
	w.next_id = int(d.next_id)
	w.core_id = int(d.core_id)
	w.storage = Items.from_json(d.storage)
	w.state = str(d.state)
	w.survival = bool(d.survival)
	w.rng.state = int(str(d.rng))
	w.research.load_dict(d.get("research", {}))
	for bd in d.buildings:
		var def = p_data.buildings.get(bd.type)
		if def == null:
			continue
		var b := Building.new()
		b.setup(int(bd.id), str(bd.type), def, Vector2i(int(bd.x), int(bd.y)), int(bd.rot))
		b.load_dict(bd)
		w._register(b)
	for ed in d.enemies:
		var id: int = w.spawn_enemy(str(ed.type), Vector2(float(ed.x), float(ed.y)), {
			"hp_mult": ed.get("hm", 1.0), "size_mult": ed.get("sm", 1.0),
			"damage_mult": ed.get("dm", 1.0), "elite": ed.get("el", false)})
		if id == 0:
			continue
		var e = w.enemies[id]
		w.enemies.erase(id)
		e.id = int(ed.id)
		e.offset = _offset_for(e.id)
		e.hp = float(ed.hp)
		e.cooldown = float(ed.cd)
		e.target = int(ed.t)
		e.think = float(ed.get("th", 0.0))
		e.facing = float(ed.f)
		w.enemies[e.id] = e
	w.next_id = int(d.next_id)
	for g in d.ghosts:
		var gd := {"type": str(g.type), "rot": int(g.rot), "recipe": str(g.recipe), "x": int(g.x), "y": int(g.y),
			"filter": Array(g.get("filter", ["", "", ""]))}
		w.ghosts[w.idx(Vector2i(gd.x, gd.y))] = gd
	w.spawn_points = []
	for s in d.spawns:
		w.spawn_points.append(Vector2i(int(s[0]), int(s[1])))
	w.waves.load_dict(d.waves)
	w.stats.load_dict(d.stats)
	w.objectives.load_dict(d.objectives)
	w.transmissions = d.get("transmissions", [])
	w.flush_caches()
	w.pathing.cooldown = float(d.get("pathing_cd", 0.0))
	w.events.clear()
	return w
