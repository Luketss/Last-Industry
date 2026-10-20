extends RefCounted
## One hostile creature. Movement follows the flow field of its path profile.

var id := 0
var type := ""
var def: Dictionary
var pos := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var cooldown := 0.0
var target := 0          ## building id being attacked (0 = none)
var think := 0.0
var facing := 0.0
var hit_time := -10.0
var profile := 0
var dead := false
var elite := false
var hp_mult := 1.0
var size_mult := 1.0
var damage_mult := 1.0
var offset := Vector2.ZERO   ## stable per-enemy spread inside a cell


func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "x": pos.x, "y": pos.y, "hp": hp, "cd": cooldown, "t": target,
		"th": think, "f": facing, "el": elite, "hm": hp_mult, "sm": size_mult, "dm": damage_mult,
	}
