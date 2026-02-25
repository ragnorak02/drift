extends Node

## Procedural audio singleton — all sounds generated via AudioStreamGenerator.
## Buses: Master(0), SFX(1), Music(2), Engine(3)

const SAMPLE_RATE := GameConstants.AUDIO_SAMPLE_RATE
const MIX_RATE := float(SAMPLE_RATE)

# -- Audio players --
var _engine_player: AudioStreamPlayer
var _engine_player2: AudioStreamPlayer
var _drift_player: AudioStreamPlayer
var _boost_player: AudioStreamPlayer
var _missile_player: AudioStreamPlayer
var _impact_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

# -- Playbacks (AudioStreamGeneratorPlayback) --
var _engine_pb: AudioStreamGeneratorPlayback
var _engine_pb2: AudioStreamGeneratorPlayback
var _drift_pb: AudioStreamGeneratorPlayback
var _boost_pb: AudioStreamGeneratorPlayback
var _missile_pb: AudioStreamGeneratorPlayback
var _impact_pb: AudioStreamGeneratorPlayback
var _ui_pb: AudioStreamGeneratorPlayback
var _music_pb: AudioStreamGeneratorPlayback

# -- Engine state --
var _engine_active := false
var _engine_phase := 0.0
var _engine_freq := GameConstants.ENGINE_BASE_FREQ
var _engine2_active := false
var _engine2_phase := 0.0
var _engine2_freq := GameConstants.ENGINE_BASE_FREQ

# -- Drift state --
var _drift_active := false
var _drift_phase := 0.0
var _drift_tier := 0
var _drift_volume := 0.0

# -- Boost state --
var _boost_active := false
var _boost_phase := 0.0
var _boost_time := 0.0
var _boost_duration := 0.3

# -- Missile launch state --
var _missile_active := false
var _missile_phase := 0.0
var _missile_time := 0.0
var _missile_duration := 0.5

# -- Impact state --
var _impact_active := false
var _impact_time := 0.0
var _impact_duration := 0.2

# -- UI beep state --
var _ui_active := false
var _ui_phase := 0.0
var _ui_time := 0.0
var _ui_duration := 0.1
var _ui_freq := 880.0
var _ui_freq2 := 0.0  # For GO chord (second tone)
var _ui_phase2 := 0.0

# -- Music state --
var _music_active := false
var _music_phase := 0.0
var _music_beat_time := 0.0
var _music_beat_idx := 0
var _music_kick_phase := 0.0
var _music_kick_active := false
var _music_kick_time := 0.0
var _music_type := 0  # 0 = race, 1 = menu

# -- Noise seed for white noise --
var _noise_seed := 12345

func _ready() -> void:
	_setup_buses()
	_create_players()
	apply_volumes()

func _setup_buses() -> void:
	# Ensure we have 4 buses: Master(0), SFX(1), Music(2), Engine(3)
	while AudioServer.bus_count < 4:
		AudioServer.add_bus()
	AudioServer.set_bus_name(1, "SFX")
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_name(2, "Music")
	AudioServer.set_bus_send(2, "Master")
	AudioServer.set_bus_name(3, "Engine")
	AudioServer.set_bus_send(3, "Master")

func _create_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.1
	player.stream = stream
	player.bus = bus_name
	player.volume_db = 0.0
	add_child(player)
	player.play()
	return player

func _create_players() -> void:
	_engine_player = _create_player("Engine")
	_engine_player2 = _create_player("Engine")
	_drift_player = _create_player("SFX")
	_boost_player = _create_player("SFX")
	_missile_player = _create_player("SFX")
	_impact_player = _create_player("SFX")
	_ui_player = _create_player("SFX")
	_music_player = _create_player("Music")

	# Get playbacks after one frame so they're ready
	_engine_pb = _engine_player.get_stream_playback()
	_engine_pb2 = _engine_player2.get_stream_playback()
	_drift_pb = _drift_player.get_stream_playback()
	_boost_pb = _boost_player.get_stream_playback()
	_missile_pb = _missile_player.get_stream_playback()
	_impact_pb = _impact_player.get_stream_playback()
	_ui_pb = _ui_player.get_stream_playback()
	_music_pb = _music_player.get_stream_playback()

func _process(delta: float) -> void:
	_fill_engine(_engine_pb, _engine_active, _engine_freq, delta)
	_fill_engine2(delta)
	_fill_drift(delta)
	_fill_boost(delta)
	_fill_missile(delta)
	_fill_impact(delta)
	_fill_ui(delta)
	_fill_music(delta)

# -- Waveform helpers --

func _sawtooth(phase: float) -> float:
	return 2.0 * fmod(phase, 1.0) - 1.0

func _sine(phase: float) -> float:
	return sin(phase * TAU)

func _noise() -> float:
	_noise_seed = (_noise_seed * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_noise_seed) / float(0x7FFFFFFF) * 2.0 - 1.0

# -- Engine --

func _fill_engine(pb: AudioStreamGeneratorPlayback, active: bool, freq: float, _delta: float) -> void:
	if not pb:
		return
	var frames := pb.get_frames_available()
	if active:
		for i in frames:
			_engine_phase += freq / MIX_RATE
			var sample := _sawtooth(_engine_phase) * 0.15
			pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			pb.push_frame(Vector2.ZERO)

func _fill_engine2(delta: float) -> void:
	if not _engine_pb2:
		return
	var frames := _engine_pb2.get_frames_available()
	if _engine2_active:
		for i in frames:
			_engine2_phase += _engine2_freq / MIX_RATE
			var sample := _sawtooth(_engine2_phase) * 0.15
			_engine_pb2.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_engine_pb2.push_frame(Vector2.ZERO)

func set_engine_state(player_id: int, speed: float, max_speed: float) -> void:
	var ratio := clampf(speed / max_speed, 0.0, 1.0)
	var freq := GameConstants.ENGINE_BASE_FREQ + ratio * (GameConstants.ENGINE_MAX_FREQ - GameConstants.ENGINE_BASE_FREQ)
	if player_id == 1:
		_engine_active = ratio > 0.01
		_engine_freq = freq
	else:
		_engine2_active = ratio > 0.01
		_engine2_freq = freq

func stop_engine(player_id: int) -> void:
	if player_id == 1:
		_engine_active = false
	else:
		_engine2_active = false

# -- Drift --

func _fill_drift(_delta: float) -> void:
	if not _drift_pb:
		return
	var frames := _drift_pb.get_frames_available()
	if _drift_active:
		var freq := 800.0 + _drift_tier * 400.0
		var vol := clampf(0.05 + _drift_tier * 0.05, 0.05, 0.2)
		for i in frames:
			_drift_phase += freq / MIX_RATE
			var tone := _sine(_drift_phase) * 0.5
			var noise_val := _noise() * 0.5
			var sample := (tone + noise_val) * vol
			_drift_pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_drift_pb.push_frame(Vector2.ZERO)

func start_drift() -> void:
	_drift_active = true
	_drift_tier = 0
	_drift_phase = 0.0

func set_drift_tier(tier: int) -> void:
	_drift_tier = tier

func stop_drift() -> void:
	_drift_active = false

# -- Boost --

func _fill_boost(_delta: float) -> void:
	if not _boost_pb:
		return
	var frames := _boost_pb.get_frames_available()
	if _boost_active:
		for i in frames:
			_boost_time += 1.0 / MIX_RATE
			if _boost_time >= _boost_duration:
				_boost_active = false
				_boost_pb.push_frame(Vector2.ZERO)
				continue
			var t := _boost_time / _boost_duration
			var freq := lerpf(400.0, 1200.0, t)
			_boost_phase += freq / MIX_RATE
			var env := 1.0 - t  # Fade out
			var sample := _sine(_boost_phase) * 0.2 * env
			_boost_pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_boost_pb.push_frame(Vector2.ZERO)

func play_boost(_strength: float) -> void:
	_boost_active = true
	_boost_time = 0.0
	_boost_phase = 0.0

# -- Missile launch --

func _fill_missile(_delta: float) -> void:
	if not _missile_pb:
		return
	var frames := _missile_pb.get_frames_available()
	if _missile_active:
		for i in frames:
			_missile_time += 1.0 / MIX_RATE
			if _missile_time >= _missile_duration:
				_missile_active = false
				_missile_pb.push_frame(Vector2.ZERO)
				continue
			var t := _missile_time / _missile_duration
			var freq := lerpf(200.0, 800.0, t)
			_missile_phase += freq / MIX_RATE
			var env := 1.0 - t * 0.5
			var sample := _sine(_missile_phase) * 0.18 * env
			_missile_pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_missile_pb.push_frame(Vector2.ZERO)

func play_missile_launch() -> void:
	_missile_active = true
	_missile_time = 0.0
	_missile_phase = 0.0

# -- Impact --

func _fill_impact(_delta: float) -> void:
	if not _impact_pb:
		return
	var frames := _impact_pb.get_frames_available()
	if _impact_active:
		for i in frames:
			_impact_time += 1.0 / MIX_RATE
			if _impact_time >= _impact_duration:
				_impact_active = false
				_impact_pb.push_frame(Vector2.ZERO)
				continue
			var t := _impact_time / _impact_duration
			var env := 1.0 - t
			var sample := _noise() * 0.25 * env
			_impact_pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_impact_pb.push_frame(Vector2.ZERO)

func play_missile_hit() -> void:
	_impact_active = true
	_impact_time = 0.0

# -- UI beeps --

func _fill_ui(_delta: float) -> void:
	if not _ui_pb:
		return
	var frames := _ui_pb.get_frames_available()
	if _ui_active:
		for i in frames:
			_ui_time += 1.0 / MIX_RATE
			if _ui_time >= _ui_duration:
				_ui_active = false
				_ui_pb.push_frame(Vector2.ZERO)
				continue
			var t := _ui_time / _ui_duration
			var env := 1.0 - t * 0.3
			_ui_phase += _ui_freq / MIX_RATE
			var sample := _sine(_ui_phase) * 0.2 * env
			if _ui_freq2 > 0.0:
				_ui_phase2 += _ui_freq2 / MIX_RATE
				sample += _sine(_ui_phase2) * 0.15 * env
			_ui_pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_ui_pb.push_frame(Vector2.ZERO)

func play_countdown_beep(is_go: bool) -> void:
	_ui_active = true
	_ui_time = 0.0
	_ui_phase = 0.0
	_ui_phase2 = 0.0
	if is_go:
		_ui_freq = 440.0
		_ui_freq2 = 880.0
		_ui_duration = 0.3
	else:
		_ui_freq = 880.0
		_ui_freq2 = 0.0
		_ui_duration = 0.1

func play_menu_select() -> void:
	_ui_active = true
	_ui_time = 0.0
	_ui_phase = 0.0
	_ui_phase2 = 0.0
	_ui_freq = 660.0
	_ui_freq2 = 990.0
	_ui_duration = 0.12

func play_menu_navigate() -> void:
	_ui_active = true
	_ui_time = 0.0
	_ui_phase = 0.0
	_ui_phase2 = 0.0
	_ui_freq = 440.0
	_ui_freq2 = 0.0
	_ui_duration = 0.06

# -- Music --

func _fill_music(_delta: float) -> void:
	if not _music_pb:
		return
	var frames := _music_pb.get_frames_available()
	if _music_active:
		var beat_len := 60.0 / GameConstants.MUSIC_BPM
		for i in frames:
			_music_beat_time += 1.0 / MIX_RATE
			if _music_beat_time >= beat_len:
				_music_beat_time -= beat_len
				_music_beat_idx = (_music_beat_idx + 1) % 8
				# Kick on beats 0, 2, 4, 6
				if _music_beat_idx % 2 == 0:
					_music_kick_active = true
					_music_kick_time = 0.0
					_music_kick_phase = 0.0

			var sample := 0.0

			# Kick drum — 60Hz sine burst with pitch decay
			if _music_kick_active:
				_music_kick_time += 1.0 / MIX_RATE
				if _music_kick_time < 0.12:
					var kick_env := 1.0 - _music_kick_time / 0.12
					var kick_freq := lerpf(120.0, 50.0, _music_kick_time / 0.12)
					_music_kick_phase += kick_freq / MIX_RATE
					sample += _sine(_music_kick_phase) * 0.2 * kick_env * kick_env
				else:
					_music_kick_active = false

			# Bass line — sawtooth at varying pitches
			var bass_notes: Array[float]
			if _music_type == 0:
				bass_notes = [110.0, 110.0, 130.81, 130.81, 146.83, 146.83, 130.81, 130.81]
			else:
				bass_notes = [82.41, 82.41, 98.0, 98.0, 110.0, 110.0, 98.0, 82.41]
			var bass_freq: float = bass_notes[_music_beat_idx]
			_music_phase += bass_freq / MIX_RATE
			sample += _sawtooth(_music_phase) * 0.08

			# Hihat on odd beats (very quiet noise burst using beat sub-timing)
			var half := beat_len * 0.5
			if _music_beat_time < 0.03 and _music_beat_idx % 2 == 1:
				sample += _noise() * 0.04

			_music_pb.push_frame(Vector2(sample, sample))
	else:
		for i in frames:
			_music_pb.push_frame(Vector2.ZERO)

func start_race_music() -> void:
	_music_active = true
	_music_beat_time = 0.0
	_music_beat_idx = 0
	_music_phase = 0.0
	_music_type = 0

func stop_race_music() -> void:
	_music_active = false

func start_menu_music() -> void:
	_music_active = true
	_music_beat_time = 0.0
	_music_beat_idx = 0
	_music_phase = 0.0
	_music_type = 1

func stop_menu_music() -> void:
	_music_active = false

# -- Volume control --

static func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(SettingsManager.master_volume))
	if AudioServer.bus_count > 1:
		var sfx_idx := AudioServer.get_bus_index("SFX")
		if sfx_idx >= 0:
			AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(SettingsManager.sfx_volume))
		var music_idx := AudioServer.get_bus_index("Music")
		if music_idx >= 0:
			AudioServer.set_bus_volume_db(music_idx, linear_to_db(SettingsManager.music_volume))
		var engine_idx := AudioServer.get_bus_index("Engine")
		if engine_idx >= 0:
			AudioServer.set_bus_volume_db(engine_idx, linear_to_db(SettingsManager.sfx_volume))
