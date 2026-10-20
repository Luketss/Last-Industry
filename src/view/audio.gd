extends Node
## Soundscape: music (menu, calm playlist, horde theme) with crossfades, sampled
## effects from assets/sfx attenuated by distance to the camera, and a procedural
## layer for ash wind, machinery hum that grows with the factory and the horde
## alarm. Sampled sounds fall back to procedural ones when an asset is missing.

const RATE := 22050.0
const SFX_DIR := "res://assets/sfx/%s.ogg"
const MUSIC_DIR := "res://assets/music/%s.ogg"
const CALM := ["calm_1", "calm_2", "calm_3", "calm_4"]
const FADE := 2.5
## sound -> [volume dB, minimum seconds between plays]
const SOUNDS := {
	"gun": [-14.0, 0.07], "gun2": [-14.0, 0.07], "cannon": [-8.0, 0.12], "arc": [-12.0, 0.1],
	"explosion": [-6.0, 0.1], "explosion2": [-6.0, 0.1], "wave": [-6.0, 1.0], "build": [-10.0, 0.05],
	"demolish": [-10.0, 0.05], "click": [-12.0, 0.03], "hover": [-20.0, 0.03], "error": [-10.0, 0.2],
	"objective": [-6.0, 0.5], "achievement": [-4.0, 0.5], "research": [-6.0, 0.5],
	"transmission": [-8.0, 1.0], "bite": [-12.0, 0.15], "die": [-12.0, 0.08],
}

var main
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _t := 0.0
var _wind := 0.0
var _wind_lp := 0.0
var _hum_level := 0.0
var _alarm := 0.0
var _shots := 0.0
var _arcs := 0.0
var _clicks := 0.0
var _rng := RandomNumberGenerator.new()
var volume := 0.8
var _sfx := {}             ## name -> AudioStreamPlayer
var _last := {}            ## name -> time of last play
var _music: Array = []     ## two players for crossfading
var _music_cur := 0
var _track := ""
var _calm_order: Array = []


func _init(p_main) -> void:
	main = p_main


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -6.0
	_player.bus = "SFX"
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()
	for name in SOUNDS:
		var path := SFX_DIR % name
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		p.stream = load(path)
		p.bus = "SFX"
		p.max_polyphony = 4
		p.volume_db = SOUNDS[name][0]
		add_child(p)
		_sfx[name] = p
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		m.finished.connect(_on_music_finished.bind(m))
		add_child(m)
		_music.append(m)
	_calm_order = CALM.duplicate()
	_calm_order.shuffle()


## Plays a sampled effect; `at` (map position) attenuates it by distance to the
## camera so far-away fights stay quiet. Returns false if the sample is missing.
func play(name: String, at = null, gain_db: float = 0.0) -> bool:
	var p: AudioStreamPlayer = _sfx.get(name)
	if p == null:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -10.0)) < float(SOUNDS[name][1]):
		return true
	var db: float = SOUNDS[name][0] + gain_db
	if at != null and main.camera != null:
		var d := Vector2(main.camera.position.x, main.camera.position.z).distance_to(at)
		var k := clampf(1.0 - (d - 14.0) / 34.0, 0.0, 1.0)
		if k <= 0.0:
			return true
		db += linear_to_db(k)
	_last[name] = now
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.93, 1.07)
	p.play()
	return true


func click() -> void:
	if not play("click"):
		_clicks = 1.0


func on_events(events: Array) -> void:
	for ev in events:
		match ev.e:
			"shot":
				if not play("gun" if _rng.randf() < 0.5 else "gun2", ev.from):
					_shots = minf(_shots + 0.6, 1.0)
			"shell":
				play("cannon", ev.from)
			"arc":
				if not play("arc", ev.points[0] if not ev.points.is_empty() else null):
					_arcs = 1.0
			"wave_start":
				_alarm = 3.5
				play("wave")
			"destroyed":
				if not play("explosion" if _rng.randf() < 0.5 else "explosion2", ev.pos):
					_shots = 1.0
			"built":
				if main.in_game:
					play("build", null)
			"removed":
				play("demolish")
			"objective":
				play("objective")
			"research":
				play("research")
			"transmission":
				play("transmission")
			"bite":
				play("bite", ev.pos)
			"spit":
				play("bite", ev.to, 2.0)
			"enemy_died":
				play("die", ev.pos, 3.0 if ev.elite else 0.0)
			"alert":
				# The core being hit gets the siren even between hordes.
				if ev.get("key", "") == "core_hit":
					_alarm = maxf(_alarm, 1.4)


func _desired_track() -> String:
	if not main.in_game or main.world == null:
		return "menu"
	if main.world.waves.active:
		return "combat"
	return _track if _track in CALM else _calm_order[0]


func _switch(track: String) -> void:
	_track = track
	var path := MUSIC_DIR % track
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = track in ["menu", "combat"]
	_music_cur = 1 - _music_cur
	var p: AudioStreamPlayer = _music[_music_cur]
	p.stream = stream
	p.volume_db = -40.0
	p.play()


func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p != _music[_music_cur] or not (_track in CALM):
		return
	# Next calm track: rotate the shuffled playlist.
	_calm_order.push_back(_calm_order.pop_front())
	_switch(_calm_order[0])


func _update_music(delta: float) -> void:
	if _music.is_empty():
		return
	var want := _desired_track()
	if want != _track:
		_switch(want)
	for i in 2:
		var p: AudioStreamPlayer = _music[i]
		if not p.playing:
			continue
		var target := 0.0 if i == _music_cur else -60.0
		p.volume_db = move_toward(p.volume_db, target, delta * 60.0 / FADE)
		if i != _music_cur and p.volume_db <= -59.0:
			p.stop()


func _process(delta: float) -> void:
	_update_music(delta)
	if _pb == null:
		return
	var w = main.world
	var active := 0
	if w != null and main.in_game:
		for k in ["miner", "crafter", "generator"]:
			for b in w.list(k):
				if b.status_level() == 0:
					active += 1
	_hum_level = lerpf(_hum_level, clampf(active / 14.0, 0.0, 1.0), 0.05)
	var n := _pb.get_frames_available()
	for i in n:
		_t += 1.0 / RATE
		# Wind: slowly modulated low-passed noise.
		_wind_lp = lerpf(_wind_lp, _rng.randf_range(-1.0, 1.0), 0.02)
		var gust := 0.55 + 0.45 * sin(_t * 0.23) * sin(_t * 0.071 + 1.0)
		var s := _wind_lp * 0.5 * gust
		# Machinery hum: 50 Hz mains plus harmonics.
		s += (sin(TAU * 50.0 * _t) * 0.5 + sin(TAU * 100.0 * _t) * 0.25 + sin(TAU * 150.0 * _t) * 0.1) * 0.05 * _hum_level
		# Gunfire: decaying noise bursts.
		if _shots > 0.0:
			s += _rng.randf_range(-1.0, 1.0) * _shots * 0.25
			_shots = maxf(_shots - 12.0 / RATE, 0.0)
		if _arcs > 0.0:
			s += signf(sin(TAU * 900.0 * _t + _rng.randf() * 2.0)) * _arcs * 0.08
			_arcs = maxf(_arcs - 5.0 / RATE, 0.0)
		if _clicks > 0.0:
			s += sin(TAU * 1400.0 * _t) * _clicks * 0.12
			_clicks = maxf(_clicks - 40.0 / RATE, 0.0)
		if _alarm > 0.0:
			var on := fmod(_alarm, 0.7) > 0.35
			if on:
				s += signf(sin(TAU * 620.0 * _t)) * 0.07
			_alarm = maxf(_alarm - 1.0 / RATE, 0.0)
		s = clampf(s * volume, -1.0, 1.0)
		_pb.push_frame(Vector2(s, s))
