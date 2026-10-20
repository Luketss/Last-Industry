extends "res://tests/test_base.gd"
## Localisation: every source text has an English and a Spanish translation that
## keeps the same placeholders, and switching language rewrites the data texts.



func _rows() -> Array:
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	check(f != null, "locale/strings.csv existe")
	var rows := []
	if f == null:
		return rows
	f.get_csv_line()
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3:
			rows.append(r)
	return rows


func test_every_text_is_translated_with_same_placeholders() -> void:
	var re := RegEx.new()
	re.compile("%[-0-9.]*[sdf%]")
	var rows := _rows()
	check(rows.size() > 300, "textos no catálogo (%d)" % rows.size())
	for r in rows:
		var want := re.search_all(r[0]).map(func(m): return m.get_string())
		for i in [1, 2]:
			check(r[i] != "", "tradução vazia para: %s" % r[0].left(50))
			check(re.search_all(r[i]).map(func(m): return m.get_string()) == want, "marcadores diferentes em: %s" % r[0].left(50))


func test_data_texts_are_in_catalog() -> void:
	var keys := {}
	for r in _rows():
		keys[r[0]] = true
	for s in data().source_texts():
		check(keys.has(s), "texto dos dados sem tradução: %s" % s.left(50))


func test_switching_language_localizes_data() -> void:
	var d = GameData.new()
	TranslationServer.set_locale("en")
	d.localize()
	eq(d.buildings.miner.name, "Miner", "nome em inglês")
	TranslationServer.set_locale("es")
	d.localize()
	eq(d.items.coal.name, "Carbón", "nome em espanhol")
	TranslationServer.set_locale("pt_BR")
	d.localize()
	eq(d.buildings.miner.name, "Mineradora", "volta ao português")
