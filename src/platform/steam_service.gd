extends Node
## Optional Steamworks integration through the GodotSteam GDExtension.
##
## Without the plugin (or without an App ID, or with Steam closed) every call is a
## no-op and the game runs fully offline. Install GodotSteam into addons/godotsteam
## and set "steam/app_id" in Project Settings (see docs/STEAM.md).

var available := false
var status := "offline"
var _steam = null


func _ready() -> void:
	var app_id := int(ProjectSettings.get_setting("steam/app_id", 0))
	if not Engine.has_singleton("Steam"):
		status = "plugin GodotSteam ausente"
		return
	if app_id <= 0:
		status = "App ID não configurado"
		return
	_steam = Engine.get_singleton("Steam")
	var r = _steam.call("steamInitEx", true, app_id) if _steam.has_method("steamInitEx") else _steam.call("steamInit")
	var ok := false
	if r is Dictionary:
		ok = int(r.get("status", 1)) == 0
		status = str(r.get("verbal", "")) if not ok else "conectado"
	else:
		ok = bool(r)
		status = "conectado" if ok else "falha ao iniciar"
	available = ok
	if available and _steam.has_method("requestCurrentStats"):
		_steam.call("requestCurrentStats")


func _process(_delta: float) -> void:
	if available:
		_steam.call("run_callbacks")


func unlock(id: String) -> void:
	if not available:
		return
	_steam.call("setAchievement", id)
	_steam.call("storeStats")


## Short status line for Steam's friends list.
func set_presence(text: String) -> void:
	if available and _steam.has_method("setRichPresence"):
		_steam.call("setRichPresence", "status", text)


func player_name() -> String:
	if available and _steam.has_method("getPersonaName"):
		return str(_steam.call("getPersonaName"))
	return ""
