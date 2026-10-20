extends Node
## Procedural soundscape (no audio assets needed): ash wind, machinery hum that
## grows with the factory, gunfire ticks, electric cracks and the horde alarm.

const RATE := 22050.0

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


func _init(p_main) -> void:
	main = p_main


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()


func click() -> void:
	_clicks = 1.0


func on_events(events: Array) -> void:
	for ev in events:
		match ev.e:
			"shot":
				_shots = minf(_shots + 0.6, 1.0)
			"arc":
				_arcs = 1.0
			"wave_start":
				_alarm = 3.5
			"destroyed":
				_shots = 1.0


func _process(_delta: float) -> void:
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
