class_name MusicDirector
extends Node
## R1 music layer. Plays the title theme or the street loop, ducks under menus
## and crossfades between them. Missing tracks are reported, never faked.

const TRACKS := {"title": "res://assets/audio/music_title.ogg", "street": "res://assets/audio/music_street.ogg"}
const BASE_DB := {"title": -9.0, "street": -14.0}
const DUCK_DB := -9.0
const SILENT_DB := -60.0

var mode: String = ""
var ducked: bool = false
var missing: Array[String] = []
var _players: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in TRACKS:
		var player := AudioStreamPlayer.new()
		player.name = "Music_" + key
		player.volume_db = SILENT_DB
		var path: String = TRACKS[key]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
			player.stream = stream
		else:
			missing.append(key)
		add_child(player)
		_players[key] = player

## The headless/dummy driver never mixes, so started playbacks would never be
## released; tests still observe mode/ducking without creating them.
static func audio_live() -> bool:
	return AudioServer.get_driver_name().to_lower() != "dummy"

func has_track(key: String) -> bool:
	return _players.has(key) and (_players[key] as AudioStreamPlayer).stream != null

func play(key: String) -> void:
	if key == mode: return
	mode = key
	for other: String in _players:
		var player: AudioStreamPlayer = _players[other]
		if player.stream == null: continue
		if other == key:
			if not player.playing and audio_live(): player.play()
			create_tween().tween_property(player, "volume_db", _target_db(other), 1.2)
		elif player.playing:
			var tween := create_tween()
			tween.tween_property(player, "volume_db", SILENT_DB, 1.0)
			tween.tween_callback(player.stop)

func set_ducked(value: bool) -> void:
	if value == ducked: return
	ducked = value
	if not _players.has(mode): return
	var player: AudioStreamPlayer = _players[mode]
	if player.stream == null or not player.playing: return
	create_tween().tween_property(player, "volume_db", _target_db(mode), 0.35)

func _target_db(key: String) -> float:
	return float(BASE_DB.get(key, -12.0)) + (DUCK_DB if ducked and key == "street" else 0.0)

func get_volume(key: String) -> float:
	return (_players[key] as AudioStreamPlayer).volume_db if _players.has(key) else SILENT_DB

func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players.values():
		if is_instance_valid(player): player.stop()
