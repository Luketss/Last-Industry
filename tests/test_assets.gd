extends "res://tests/test_base.gd"
## Third-party assets: every model, sound, track and icon the game asks for is
## present, and every pack in use is credited (assets/sources.json).

const Kit = preload("res://src/view/kit.gd")
const Meshes = preload("res://src/view/meshes.gd")
const GameAudio = preload("res://src/view/audio.gd")
const UiTheme = preload("res://src/ui/ui_theme.gd")
const WorldView = preload("res://src/view/world_view.gd")


func _sources() -> Dictionary:
	var f := FileAccess.open("res://assets/sources.json", FileAccess.READ)
	check(f != null, "assets/sources.json existe")
	return JSON.parse_string(f.get_as_text()) if f != null else {}


func test_every_structure_builds_with_kit_models() -> void:
	check(Kit.has("factory/machine"), "kits 3D importados")
	var d = data()
	for type in d.buildings:
		var h: Dictionary = Meshes.build(type, d.buildings[type], 1)
		check(h.root.get_child_count() > 0, "%s tem modelo" % type)
		check(float(h.h) > 0.0, "%s tem altura para a barra de vida" % type)
		if d.buildings[type].get("kind", "") in ["turret_gun"]:
			check(h.head != null, "%s tem cabeça giratória" % type)
		h.root.free()


func test_kit_models_fit_their_footprint() -> void:
	var parent := Node3D.new()
	var p := Kit.place(parent, "city/building-c", Vector3.ZERO, Vector3(2.0, 0.0, 1.0), PI * 0.5)
	check(p != null, "modelo instanciado")
	var box: AABB = Kit.aabb("city/building-c")
	# Turned 90°, the model's Z extent must fit the 2.0 slot and its X extent the 1.0 slot.
	check(box.size.z * p.scale.x <= 2.0001 and box.size.x * p.scale.x <= 1.0001, "cabe na área (%s)" % p.scale)
	check(Kit.place(parent, "factory/nao-existe", Vector3.ZERO, Vector3.ONE) == null, "modelo ausente devolve null")
	var m := Kit.merged_mesh("city/building-a")
	check(m != null and m.get_surface_count() == 1, "malha combinada para MultiMesh")
	parent.free()


func test_every_enemy_has_a_creature_model() -> void:
	for type in data().enemies:
		var m := Kit.enemy_mesh(type)
		check(m != null, "inimigo %s tem modelo" % type)
		if m != null:
			var box := m.get_aabb()
			check(absf(box.position.y) < 0.01, "%s apoiado no chão" % type)
			check(maxf(box.size.x, box.size.z) <= 1.001, "%s normalizado" % type)


func test_ruin_models_exist() -> void:
	for name in WorldView.RUIN_MODELS:
		check(Kit.has(name), "ruína %s" % name)


func test_sounds_and_music_exist() -> void:
	for name in GameAudio.SOUNDS:
		check(ResourceLoader.exists(GameAudio.SFX_DIR % name), "efeito %s" % name)
	for name in GameAudio.CALM + ["menu", "combat"]:
		check(ResourceLoader.exists(GameAudio.MUSIC_DIR % name), "música %s" % name)


func test_ui_assets_exist() -> void:
	check(UiTheme.font() != null, "fonte de títulos")
	check(UiTheme.font().fallbacks.size() > 0, "fonte tem fallback para acentos e símbolos")
	for name in ["panel", "panel_info", "button", "button_hover", "button_pressed", "button_disabled"]:
		check(UiTheme.texture(UiTheme.UI % name) != null, "moldura %s" % name)
	for item in data().items:
		check(UiTheme.icon("items/" + item) != null, "ícone do item %s" % item)
	for type in data().game.build_menu:
		check(UiTheme.icon("buildings/" + type) != null, "ícone de %s" % type)
	for n in ["gear", "trophy", "exitRight", "right", "import", "question", "information"]:
		check(UiTheme.icon("ui/" + n) != null, "ícone %s" % n)


func test_every_pack_is_credited_with_license() -> void:
	var src := _sources()
	check(src.size() >= 10, "pacotes listados (%d)" % src.size())
	for k in src:
		var e: Dictionary = src[k]
		check(str(e.get("page", "")).begins_with("https://opengameart.org/"), "%s: página de origem" % k)
		check(str(e.get("license", "")) in ["CC0", "CC-BY 4.0", "CC-BY 3.0", "OGA-BY 3.0"], "%s: licença permite uso comercial sem share-alike (%s)" % [k, e.get("license")])
		check(str(e.get("author", "")) != "", "%s: autor" % k)
