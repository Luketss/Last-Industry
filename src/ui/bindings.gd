extends RefCounted
## Remappable keyboard bindings, persisted in Settings ("bindings").
## Esc, Ctrl+C/Ctrl+V, Shift modifiers, mouse buttons and the arrow keys are fixed.

const Settings = preload("res://src/ui/settings.gd")

## Order defines how the controls list is shown in the options.
const ACTIONS := [
	["cam_up", "Câmera: cima", KEY_W], ["cam_down", "Câmera: baixo", KEY_S],
	["cam_left", "Câmera: esquerda", KEY_A], ["cam_right", "Câmera: direita", KEY_D],
	["cam_rot_left", "Câmera: girar à esquerda", KEY_Z], ["cam_rot_right", "Câmera: girar à direita", KEY_C],
	["rotate", "Girar estrutura / planta", KEY_R], ["pipette", "Conta-gotas", KEY_Q],
	["trace", "Rastrear fluxo", KEY_V], ["blueprint", "Reutilizar planta", KEY_B],
	["rebuild", "Reconstruir ruínas", KEY_G], ["demolish", "Demolir seleção", KEY_DELETE],
	["pause", "Pausar", KEY_SPACE], ["speed_up", "Acelerar", KEY_PERIOD], ["speed_down", "Desacelerar", KEY_COMMA],
	["next_wave", "Chamar próxima horda", KEY_N], ["stats", "Estatísticas", KEY_TAB],
	["research", "Árvore de pesquisa", KEY_T], ["help", "Ajuda", KEY_H], ["debug", "Depuração", KEY_F3],
	["save", "Salvar", KEY_F5], ["load", "Carregar", KEY_F9],
	["slot1", "Construção 1", KEY_1], ["slot2", "Construção 2", KEY_2], ["slot3", "Construção 3", KEY_3],
	["slot4", "Construção 4", KEY_4], ["slot5", "Construção 5", KEY_5], ["slot6", "Construção 6", KEY_6],
	["slot7", "Construção 7", KEY_7], ["slot8", "Construção 8", KEY_8], ["slot9", "Construção 9", KEY_9],
	["slot10", "Construção 10", KEY_0], ["slot11", "Construção 11", KEY_MINUS], ["slot12", "Construção 12", KEY_EQUAL],
]

static var _keys := {}


static func reload() -> void:
	_keys = {}
	for a in ACTIONS:
		_keys[a[0]] = a[2]
	var saved = Settings.get_value("bindings")
	if saved is Dictionary:
		for k in saved:
			if _keys.has(k):
				_keys[k] = int(saved[k])


static func key(action: String) -> int:
	if _keys.is_empty():
		reload()
	return int(_keys.get(action, KEY_NONE))


static func is_action(e: InputEventKey, action: String) -> bool:
	return e.keycode == key(action) and not e.ctrl_pressed


static func held(action: String) -> bool:
	return Input.is_key_pressed(key(action))


## Action bound to a key event, or "" (ignores Ctrl combinations).
static func action_for(e: InputEventKey) -> String:
	if e.ctrl_pressed:
		return ""
	if _keys.is_empty():
		reload()
	for a in ACTIONS:
		if _keys[a[0]] == e.keycode:
			return a[0]
	return ""


## Binds `action` to `keycode`. A key already used by another action is swapped
## with it, so no two actions ever share a key.
static func rebind(action: String, keycode: int) -> void:
	if _keys.is_empty():
		reload()
	var old: int = _keys[action]
	for a in _keys:
		if a != action and _keys[a] == keycode:
			_keys[a] = old
	_keys[action] = keycode
	Settings.set_value("bindings", _keys.duplicate())


static func reset() -> void:
	Settings.set_value("bindings", {})
	reload()


const KEY_LABELS := {
	KEY_SPACE: "Espaço", KEY_PERIOD: ".", KEY_COMMA: ",", KEY_MINUS: "-", KEY_EQUAL: "=",
	KEY_DELETE: "Del", KEY_BACKSPACE: "Backspace", KEY_ENTER: "Enter", KEY_SLASH: "/",
	KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
}


static func label(action: String) -> String:
	var k := key(action)
	if k == KEY_NONE:
		return "—"
	return KEY_LABELS.get(k, OS.get_keycode_string(k))
