extends Node
## Progress through the current playthrough (autoloaded as "Progress").
## Survives level reloads from dying or resting, so you come back at the last
## checkpoint with what you've found; starting a new game from the main menu
## resets it. Not saved to disk.

## The checkpoint the player last rested at, or "" for the level start.
var checkpoint_id := ""
var relic_taken := false
var illusory_wall_revealed := false
var hints_shown := false


func reset() -> void:
	checkpoint_id = ""
	relic_taken = false
	illusory_wall_revealed = false
	hints_shown = false
