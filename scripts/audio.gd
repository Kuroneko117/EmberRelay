extends Node
## Small, self-contained synthesizer for Ember Relay.
## Sound data is generated once; playing an effect never synthesizes new audio.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 8
const MUSIC_SECONDS: float = 24.0
const BEAT_SECONDS: float = 0.75

var muted: bool = false
var _music: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _next_player: int = 0
var _intensity: float = 0.0
var _region: int = 0

func _exit_tree() -> void:
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
	_sounds.clear()


func _ready() -> void:
	for index: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.volume_db = -9.0
		add_child(player)
		_players.append(player)
	_build_effects()
	_music = AudioStreamPlayer.new()
	_music.name = "EmberRadio"
	var score: AudioStreamOggVorbis = preload("res://assets/music/last-light.ogg")
	score.loop = true
	_music.stream = score
	_music.volume_db = -80.0 if muted else -20.0
	add_child(_music)
	if AudioServer.get_driver_name()!="Dummy":
		_music.play()


func play_sfx(sound_name: String) -> void:
	if muted or not _sounds.has(sound_name) or _players.is_empty():
		return
	var chosen: AudioStreamPlayer = _players[_next_player]
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			chosen = player
			break
	_next_player = (_next_player + 1) % _players.size()
	chosen.stop()
	chosen.stream = _sounds[sound_name] as AudioStreamWAV
	chosen.volume_db = -9.0
	chosen.play()


func set_muted(value: bool) -> void:
	muted = value
	if is_instance_valid(_music):
		_music.volume_db = -80.0 if muted else lerpf(-20.0, -16.5, _intensity)
	if muted:
		for player: AudioStreamPlayer in _players:
			player.stop()


func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if is_instance_valid(_music):
		_music.volume_db = -80.0 if muted else lerpf(-20.0, -16.5, _intensity)

func set_region(region: int) -> void:
	if region==_region or not is_instance_valid(_music): return
	_region = region
	_music.stop()
	var score: AudioStreamOggVorbis = preload("res://assets/music/skywater.ogg") if region==1 else preload("res://assets/music/last-light.ogg")
	score.loop = true
	_music.stream = score
	if AudioServer.get_driver_name()!="Dummy": _music.play()


func _make_stream(samples: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index], -0.96, 0.96) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


func _add_note(samples: PackedFloat32Array, start: float, duration: float, midi_note: int, gain: float, voice: int) -> void:
	var first_sample: int = int(start * SAMPLE_RATE)
	var count: int = int(duration * SAMPLE_RATE)
	var phase_step: float = TAU * _frequency(midi_note) / float(SAMPLE_RATE)
	var phase: float = 0.0
	for index: int in range(count):
		var destination: int = (first_sample + index) % samples.size()
		var progress: float = float(index) / float(count)
		var time: float = float(index) / float(SAMPLE_RATE)
		var attack: float = minf(time / 0.012, 1.0)
		var release: float = minf((duration - time) / 0.09, 1.0)
		var envelope: float = attack * release
		var wave: float = 0.0
		match voice:
			0: # Warm bass: almost sinusoidal, with a little second harmonic.
				wave = sin(phase) * 0.86 + sin(phase * 2.0) * 0.14
				envelope *= 1.0 - progress * 0.4
			1: # Rounded pulse: quiet overtones keep headphones comfortable.
				wave = sin(phase) * 0.76 + sin(phase * 3.0) * 0.17 + sin(phase * 5.0) * 0.07
				envelope *= (1.0 - progress) * (1.0 - progress)
			2: # A soft bell, used for the sparse lead.
				wave = sin(phase) * 0.78 + sin(phase * 2.0) * 0.15 + sin(phase * 4.0) * 0.07
				envelope *= 1.0 - progress * 0.8
			3: # Quiet pad with slow onset.
				wave = sin(phase) * 0.82 + sin(phase * 1.002) * 0.18
				envelope = minf(time / 0.35, 1.0) * minf((duration - time) / 0.5, 1.0)
		phase += phase_step
		samples[destination] += wave * envelope * gain


func _add_drum(samples: PackedFloat32Array, start: float, kick: bool, gain: float) -> void:
	var first_sample: int = int(start * SAMPLE_RATE)
	var duration: float = 0.17 if kick else 0.045
	var count: int = int(duration * SAMPLE_RATE)
	var phase: float = 0.0
	var seed_value: int = 12345 + first_sample
	var filtered_noise: float = 0.0
	for index: int in range(count):
		var progress: float = float(index) / float(count)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		envelope *= minf(float(index) / 44.0, 1.0)
		var wave: float
		if kick:
			phase += TAU * lerpf(115.0, 43.0, minf(progress * 3.0, 1.0)) / float(SAMPLE_RATE)
			wave = sin(phase)
		else:
			seed_value = (seed_value * 1664525 + 1013904223) & 0xffffffff
			var noise: float = float(seed_value) / 2147483648.0 - 1.0
			filtered_noise = lerpf(filtered_noise, noise, 0.35)
			wave = noise - filtered_noise
		var destination: int = (first_sample + index) % samples.size()
		samples[destination] += wave * envelope * gain


func _build_music() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(MUSIC_SECONDS * SAMPLE_RATE))
	# Eight bars at 80 BPM: Am / F / C / G, then a gentle returning phrase.
	var roots: Array[int] = [45, 41, 48, 43, 45, 41, 50, 40]
	var thirds: Array[int] = [3, 4, 4, 4, 3, 4, 3, 4]
	var arp_steps: Array[int] = [0, 7, 12, 7, 0, 7, 12, 7]
	var melody: Array[int] = [76, 72, 69, 72, 76, 79, 74, 71, 76, 79, 81, 76, 77, 74, 71, 68]
	for bar: int in range(8):
		var bar_start: float = float(bar) * 3.0
		var root_note: int = roots[bar]
		_add_note(samples, bar_start, 2.8, root_note, 0.30, 0)
		_add_note(samples, bar_start, 2.95, root_note + 24, 0.035, 3)
		_add_note(samples, bar_start, 2.95, root_note + 24 + thirds[bar], 0.028, 3)
		for step: int in range(8):
			var note: int = root_note + 24 + arp_steps[step]
			if step == 3 or step == 7:
				note = root_note + 24 + thirds[bar]
			_add_note(samples, bar_start + float(step) * 0.375, 0.31, note, 0.105, 1)
			# The hats stay sparse and the kick never masks attack effects.
			if step % 2 == 1:
				_add_drum(samples, bar_start + float(step) * 0.375, false, 0.038)
		_add_note(samples, bar_start + 0.375, 1.05, melody[bar * 2], 0.13, 2)
		_add_note(samples, bar_start + 1.875, 0.95, melody[bar * 2 + 1], 0.11, 2)
		_add_drum(samples, bar_start, true, 0.13)
		_add_drum(samples, bar_start + BEAT_SECONDS * 2.0, true, 0.09)
	return _make_stream(samples, true)


func _build_effects() -> void:
	var specifications: Dictionary = {
		"slash": [0.15, 1080.0, 190.0, 0.57, 0.46],
		"jump": [0.20, 220.0, 660.0, 0.0, 0.50],
		"dash": [0.24, 570.0, 100.0, 0.55, 0.50],
		"pulse": [0.65, 95.0, 350.0, 0.06, 0.65],
		"hurt": [0.28, 155.0, 58.0, 0.23, 0.55],
		"kill": [0.20, 350.0, 85.0, 0.28, 0.50],
		"pickup": [0.36, 659.25, 1318.51, 0.0, 0.41],
		"checkpoint": [0.85, 440.0, 880.0, 0.0, 0.48],
		"win": [1.40, 440.0, 880.0, 0.0, 0.52],
		"click": [0.065, 740.0, 440.0, 0.0, 0.29],
		"boss": [0.85, 90.0, 47.0, 0.18, 0.65],
		"warning": [0.13, 620.0, 790.0, 0.0, 0.25],
		"enemy_attack": [0.19, 330.0, 100.0, 0.4, 0.46],
		"slam": [0.31, 100.0, 38.0, 0.45, 0.65],
		"shoot": [0.18, 480.0, 160.0, 0.1, 0.4],
		"boss_phase": [0.9, 68.0, 190.0, 0.15, 0.6],
		"enemy_hit": [0.08, 390.0, 120.0, 0.55, 0.35],
		"enemy_die": [0.18, 210.0, 60.0, 0.6, 0.4],
		"parry": [0.43, 1600.0, 440.0, 0.12, 0.6],
		"guard": [0.14, 700.0, 1100.0, 0.0, 0.35],
		"burst": [0.85, 60.0, 240.0, 0.3, 0.75],
		"chest": [0.5, 520.0, 1560.0, 0.0, 0.5],
	}
	for sound_name: String in specifications:
		var spec: Array = specifications[sound_name]
		_sounds[sound_name] = _build_effect(sound_name, float(spec[0]), float(spec[1]), float(spec[2]), float(spec[3]), float(spec[4]))


func _build_effect(sound_name: String, duration: float, first_frequency: float, last_frequency: float, noise_amount: float, gain: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var sub_phase: float = 0.0
	var seed_value: int = 76123
	var filtered_noise: float = 0.0
	var reward_notes: Array[int] = [69, 72, 76, 81]
	for index: int in range(count):
		var progress: float = float(index) / float(count)
		var time: float = float(index) / float(SAMPLE_RATE)
		var frequency: float = lerpf(first_frequency, last_frequency, progress)
		var envelope: float = minf(time / 0.006, 1.0) * pow(1.0 - progress, 1.6)
		if sound_name == "pickup":
			frequency = 659.25 if progress < 0.45 else 987.77
		elif sound_name == "checkpoint" or sound_name == "win":
			var segment: int = mini(int(progress * 4.0), 3)
			frequency = _frequency(reward_notes[segment])
			var local_progress: float = fmod(progress * 4.0, 1.0)
			envelope *= minf(local_progress * 18.0, 1.0) * minf((1.0 - local_progress) * 10.0, 1.0)
		elif sound_name == "hurt":
			frequency += sin(time * 120.0) * 24.0
		elif sound_name == "boss":
			frequency += sin(time * 27.0) * 9.0
		phase += TAU * frequency / float(SAMPLE_RATE)
		sub_phase += TAU * 57.0 / float(SAMPLE_RATE)
		seed_value = (seed_value * 1664525 + 1013904223) & 0xffffffff
		var noise: float = float(seed_value) / 2147483648.0 - 1.0
		filtered_noise = lerpf(filtered_noise, noise, 0.5)
		var tone: float = sin(phase) * 0.78 + sin(phase * 2.0) * 0.16 + sin(phase * 3.0) * 0.06
		if sound_name == "pulse":
			tone = tone * 0.65 + sin(sub_phase) * 0.35
		elif sound_name == "boss":
			tone = tone * 0.65 + sin(phase * 0.502) * 0.35
		samples[index] = (tone * (1.0 - noise_amount) + filtered_noise * noise_amount) * envelope * gain
	return _make_stream(samples)
