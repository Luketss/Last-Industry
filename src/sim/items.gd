extends RefCounted
## Helpers for item-count dictionaries ({item_id: int}).


static func count(inv: Dictionary, item: String) -> int:
	return int(inv.get(item, 0))


static func add(inv: Dictionary, item: String, n: int = 1) -> void:
	inv[item] = int(inv.get(item, 0)) + n


static func take(inv: Dictionary, item: String, n: int = 1) -> bool:
	var have := int(inv.get(item, 0))
	if have < n:
		return false
	if have == n:
		inv.erase(item)
	else:
		inv[item] = have - n
	return true


static func total(inv: Dictionary) -> int:
	var t := 0
	for v in inv.values():
		t += int(v)
	return t


static func has_all(inv: Dictionary, req: Dictionary, mult: int = 1) -> bool:
	for k in req:
		if int(inv.get(k, 0)) < int(req[k]) * mult:
			return false
	return true


## JSON round trips turn ints into floats; normalise back.
static func from_json(d) -> Dictionary:
	var r := {}
	if d is Dictionary:
		for k in d:
			r[str(k)] = int(d[k])
	return r
