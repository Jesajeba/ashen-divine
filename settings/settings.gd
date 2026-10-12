extends Node
## Player-facing game settings (autoloaded as "Settings"), saved to
## user://settings.cfg alongside the audio settings. Master volume lives in
## Audio; this holds everything else.

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const BASE_MOUSE_SENSITIVITY := 0.002 ## Radians turned per pixel at a sensitivity of 1.
const MIN_MOUSE_SENSITIVITY := 0.2
const MAX_MOUSE_SENSITIVITY := 3.0

## Multiplier on BASE_MOUSE_SENSITIVITY. Change with set_mouse_sensitivity().
var mouse_sensitivity := 1.0


func _ready() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Missing on first run; defaults are used then.
	mouse_sensitivity = clampf(config.get_value("controls", "mouse_sensitivity", 1.0),
			MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)


## Radians to turn per pixel of mouse movement.
func get_look_speed() -> float:
	return BASE_MOUSE_SENSITIVITY * mouse_sensitivity


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Keep the other saved settings.
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.save(SETTINGS_PATH)
	changed.emit()
