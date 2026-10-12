extends Node
## Global audio player (autoloaded as "Audio"). Plays sound effects and music
## by name.
##
## MIXING: every sound is listed once in SOUNDS below with its volume, so the
## whole game can be balanced from this table. volume_db is in decibels:
## 0 is the file as-is, -6 is about half as loud, +6 about twice as loud.
## Several names can share a file at different volumes/pitches (e.g. the
## player's and enemies' swings).
##
## Overall levels live on the "Music" and "SFX" audio buses (Audio tab at
## the bottom of the editor), defined in res://default_bus_layout.tres.
##
## The player-facing master volume (set_master_volume, from the pause menu)
## is applied to the Master bus and saved to user://settings.cfg.

## files: one is picked at random each time.
## pitch: base pitch (1 = normal); pitch_variation: random +/- around it, so
## repeated sounds don't sound identical.
const SOUNDS := {
	# Player
	"sword_swoosh": { "files": ["res://sfx/sword_swoosh_1.mp3", "res://sfx/swrod_swoosh_2.mp3"],
		"volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.08 },
	"heavy_swoosh": { "files": ["res://sfx/sword_swoosh_1.mp3", "res://sfx/swrod_swoosh_2.mp3"],
		"volume_db": 2.0, "pitch": 0.75, "pitch_variation": 0.04 },
	"dodge": { "files": ["res://sfx/sword_swoosh_1.mp3", "res://sfx/swrod_swoosh_2.mp3"],
		"volume_db": -8.0, "pitch": 0.6, "pitch_variation": 0.05 },
	"footstep": { "files": ["res://sfx/footstep.mp3"], "volume_db": -6.0, "pitch": 1.0, "pitch_variation": 0.12 },
	"footstep_land": { "files": ["res://sfx/footstep.mp3"], "volume_db": -1.0, "pitch": 0.8, "pitch_variation": 0.05 },
	"gunshot": { "files": ["res://sfx/gunshot.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.05 },
	"parry": { "files": ["res://sfx/parry.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.0 },
	"potion_drink": { "files": ["res://sfx/potion_drink.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.0 },
	"player_hurt": { "files": ["res://sfx/blood_splatter.mp3", "res://sfx/blood_splatter_2.mp3", "res://sfx/blood_splatter_3.mp3"],
		"volume_db": 0.0, "pitch": 0.8, "pitch_variation": 0.05 },
	"player_death": { "files": ["res://sfx/kill_effect_layer.mp3"], "volume_db": 0.0, "pitch": 0.7, "pitch_variation": 0.0 },
	"relic_pickup": { "files": ["res://sfx/spell_cast.mp3"], "volume_db": 0.0, "pitch": 1.4, "pitch_variation": 0.0 },
	"illusory_wall": { "files": ["res://sfx/spell_cast.mp3"], "volume_db": -2.0, "pitch": 0.6, "pitch_variation": 0.0 },
	# Enemies (played at their position)
	"enemy_swing": { "files": ["res://sfx/sword_swoosh_1.mp3", "res://sfx/swrod_swoosh_2.mp3"],
		"volume_db": 0.0, "pitch": 0.8, "pitch_variation": 0.08 },
	"enemy_hit": { "files": ["res://sfx/blood_splatter.mp3", "res://sfx/blood_splatter_2.mp3", "res://sfx/blood_splatter_3.mp3"],
		"volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.1 },
	"enemy_hit_critical": { "files": ["res://sfx/blood_splatter.mp3", "res://sfx/blood_splatter_2.mp3", "res://sfx/blood_splatter_3.mp3"],
		"volume_db": 3.0, "pitch": 0.85, "pitch_variation": 0.05 },
	"enemy_death": { "files": ["res://sfx/kill_effect_layer.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.05 },
	"spell_cast": { "files": ["res://sfx/spell_cast.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.08 },
	"orb_explosion": { "files": ["res://sfx/explosion_medium.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.1 },
	# Boss
	"reaper_voice": { "files": ["res://sfx/demon_voice_1.mp3", "res://sfx/demon_voice_2.mp3"],
		"volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.06 },
	"boss_phase_two": { "files": ["res://sfx/phase2_scream.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.0 },
	"boss_land": { "files": ["res://sfx/explosion_medium.mp3"], "volume_db": 0.0, "pitch": 0.55, "pitch_variation": 0.0 },
	"boss_death_scream": { "files": ["res://sfx/phase2_scream.mp3"], "volume_db": 0.0, "pitch": 0.75, "pitch_variation": 0.0 },
	"blood_gush": { "files": ["res://sfx/blood_splatter.mp3", "res://sfx/blood_splatter_2.mp3", "res://sfx/blood_splatter_3.mp3"],
		"volume_db": -3.0, "pitch": 0.7, "pitch_variation": 0.15 },
	"boss_death": { "files": ["res://sfx/explosion_large.mp3"], "volume_db": 0.0, "pitch": 1.0, "pitch_variation": 0.0 },
}

## Music tracks loop. volume_db works as for SOUNDS.
const MUSIC := {
	"main": { "file": "res://sfx/music/main_song.mp3", "volume_db": -6.0 },
	"boss": { "file": "res://sfx/music/boss_song.mp3", "volume_db": -6.0 },
}

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MASTER_VOLUME := 0.5

## 0 to 1. Change with set_master_volume().
var master_volume := DEFAULT_MASTER_VOLUME

## How far away (meters) positional sounds stay at full volume before fading.
@export var unit_size := 6.0
@export var max_distance := 45.0

var _streams := {} ## path -> AudioStream
var _music_players: Array[AudioStreamPlayer] = []
var _music_current := 0
var _music_name := ""
var _music_tweens: Array[Tween] = [null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep playing through pauses and hit-stop.
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		add_child(player)
		_music_players.append(player)

	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Missing on first run; the default is used then.
	_apply_master_volume(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME))


## Sets the overall volume (0 to 1) and saves it.
func set_master_volume(volume: float) -> void:
	_apply_master_volume(volume)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Keep any other settings already saved.
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)


func _apply_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


## Plays a sound effect without position (heard the same everywhere): for the
## player's own actions.
func play(sound: String) -> void:
	var entry := _entry(sound)
	if entry.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS
	_configure(player, entry)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## Plays a sound effect at a point in the world: louder when close.
func play_at(sound: String, position: Vector3) -> void:
	var entry := _entry(sound)
	if entry.is_empty():
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = SFX_BUS
	player.unit_size = unit_size
	player.max_distance = max_distance
	_configure(player, entry)
	# Parented to the current scene so it's cleaned up if the level reloads.
	var parent := get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(player)
	player.global_position = position
	player.play()
	player.finished.connect(player.queue_free)


## Switches to a looping music track, crossfading over fade seconds. Does
## nothing if that track is already playing.
func play_music(track: String, fade := 1.5) -> void:
	if track == _music_name or not MUSIC.has(track):
		if not MUSIC.has(track):
			push_warning("Audio: unknown music track '%s'." % track)
		return
	_music_name = track
	var entry: Dictionary = MUSIC[track]
	var stream: AudioStream = _load(entry.file).duplicate()
	if "loop" in stream:
		stream.set("loop", true)

	_fade_out(_music_current, fade)
	_music_current = 1 - _music_current
	var player := _music_players[_music_current]
	player.stream = stream
	player.volume_db = -60.0
	player.play()
	_set_music_tween(_music_current, player.create_tween())
	_music_tweens[_music_current].tween_property(player, "volume_db", float(entry.volume_db), fade)


func stop_music(fade := 1.5) -> void:
	_music_name = ""
	_fade_out(_music_current, fade)


func _fade_out(index: int, fade: float) -> void:
	var player := _music_players[index]
	if not player.playing:
		return
	_set_music_tween(index, player.create_tween())
	_music_tweens[index].tween_property(player, "volume_db", -60.0, fade)
	_music_tweens[index].tween_callback(player.stop)


func _set_music_tween(index: int, tween: Tween) -> void:
	if _music_tweens[index]:
		_music_tweens[index].kill()
	_music_tweens[index] = tween


func _entry(sound: String) -> Dictionary:
	if not SOUNDS.has(sound):
		push_warning("Audio: unknown sound '%s'." % sound)
		return {}
	return SOUNDS[sound]


func _configure(player: Node, entry: Dictionary) -> void:
	var files: Array = entry.files
	player.set("stream", _load(files.pick_random()))
	player.set("volume_db", float(entry.volume_db))
	var variation: float = entry.get("pitch_variation", 0.0)
	player.set("pitch_scale", float(entry.get("pitch", 1.0)) * randf_range(1.0 - variation, 1.0 + variation))


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]
