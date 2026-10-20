extends RefCounted
## The Genesis structure ends the campaign. Once built (research "Protocolo
## Genesis") it needs continuous power for `charge_time` seconds; while it charges
## the nests send surges from every direction. At full charge the simulation stops
## in state "genesis" until the player picks one of the three endings
## (World.choose_ending).
##
## Data terminals scattered near the ruins hold the story behind Genesis: reading
## one needs a structure within TERMINAL_REACH and grants a small salvage reward.

const I18n = preload("res://src/ui/i18n.gd")

const ENDINGS := ["restore", "destroy", "fortress"]
const SURGE_EVERY := 22.0
const TERMINAL_REACH := 7.0
const TERMINAL_REWARD := {"iron_plate": 40, "gear": 15}


func request(w) -> void:
	for b in w.list("genesis"):
		b.power_req = float(b.def.power) if b.enabled and b.progress < 1.0 else 0.0


func step(w, dt: float) -> void:
	for b in w.list("genesis"):
		if b.progress >= 1.0:
			continue
		if not b.enabled:
			b.status = "desligado"
			continue
		if b.power_sat < 0.5:
			b.status = "sem energia" if b.power_sat <= 0.0 else "energia baixa"
			continue
		if b.progress == 0.0:
			w.trigger_lore("genesis_start")
			w.add_alert("genesis", I18n.t("Genesis em ativação: as hordas estão convergindo!"), "danger", b.center(), 0.0)
			b.cooldown = 4.0
		b.status = "ativando"
		b.progress = minf(b.progress + dt * b.power_sat / float(b.def.charge_time), 1.0)
		b.cooldown -= dt
		if b.cooldown <= 0.0:
			b.cooldown = SURGE_EVERY
			_surge(w, b.progress)
		if b.progress >= 1.0:
			b.status = "pronta"
			w.state = "genesis"
			w.trigger_lore("genesis_ready")
			w.events.append({"e": "genesis_ready", "id": b.id})


## Creatures rush in from every nest, more of them the closer Genesis gets.
func _surge(w, progress: float) -> void:
	var n := 2 + int(progress * 5.0)
	for sp in w.spawn_points.size():
		for i in n:
			var t := "crawler"
			if i % 4 == 3:
				t = "spitter"
			elif i % 3 == 2:
				t = "runner"
			w.waves._spawn_at(w, t, sp, {})
		if progress > 0.5:
			w.waves._spawn_at(w, "brute", sp, {})


## Data terminals ------------------------------------------------------------

## Reads the terminal at cell `c`. Returns "" on success or the reason it failed.
func read_terminal(w, c: Vector2i) -> String:
	var key: int = w.idx(c)
	var t = w.terminals.get(key)
	if t == null:
		return I18n.t("Nenhum terminal aqui")
	if t.read:
		return I18n.t("Terminal já decodificado")
	if not w.is_revealed(c) or not near_structure(w, c):
		return I18n.t("Fora de alcance: construa algo a até 7 tiles do terminal")
	t.read = true
	for k in TERMINAL_REWARD:
		w.storage[k] = int(w.storage.get(k, 0)) + int(TERMINAL_REWARD[k])
	w.stats.terminals += 1
	w.trigger_lore("terminal:%d" % int(t.n))
	w.add_alert("terminal", I18n.t("Terminal decodificado: arquivo recuperado e sucata recolhida"), "info", Vector2(c) + Vector2(0.5, 0.5), 0.0)
	w.events.append({"e": "terminal", "key": key})
	return ""


static func near_structure(w, c: Vector2i) -> bool:
	var p := Vector2(c) + Vector2(0.5, 0.5)
	for b in w.buildings.values():
		if b.dist_to(p) <= TERMINAL_REACH:
			return true
	return false
