extends Node
## Starts a music track (see Audio.MUSIC) when the scene loads, e.g. a level's
## background music. Also restores it after a death reload interrupted
## another track, like the boss theme.

@export var track := "main"
@export var fade := 2.0


func _ready() -> void:
	Audio.play_music(track, fade)
