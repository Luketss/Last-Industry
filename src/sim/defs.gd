extends RefCounted
## Shared constants for the simulation layer.

const TICK_RATE := 20
const DT := 1.0 / TICK_RATE

## rot 0 = east (+x), 1 = south (+y), 2 = west (-x), 3 = north (-y)
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DIR_NAMES := ["Leste", "Sul", "Oeste", "Norte"]

const T_GROUND := 0
const T_IRON := 1
const T_COAL := 2
const T_ROCK := 3
const ORE_ITEM := {1: "iron_ore", 2: "coal"}

const BELT_SPACING := 0.25
const INF := 1.0e20


static func dir_vec(rot: int) -> Vector2i:
	return DIRS[posmod(rot, 4)]


## Compass label for a map position relative to the map centre.
static func compass(p: Vector2, w: int, h: int) -> String:
	var d := p - Vector2(w * 0.5, h * 0.5)
	if absf(d.x) > absf(d.y):
		return "Leste" if d.x > 0 else "Oeste"
	return "Sul" if d.y > 0 else "Norte"
