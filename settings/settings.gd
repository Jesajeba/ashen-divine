extends Node
## Player-facing game settings (autoloaded as "Settings"), saved to
## user://settings.cfg alongside the audio settings. Master volume lives in
## Audio; this holds everything else: mouse sensitivity and display options.

signal changed

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

const SETTINGS_PATH := "user://settings.cfg"
const BASE_MOUSE_SENSITIVITY := 0.002 ## Radians turned per pixel at a sensitivity of 1.
const MIN_MOUSE_SENSITIVITY := 0.2
const MAX_MOUSE_SENSITIVITY := 3.0
const WINDOW_MODE_NAMES := ["Windowed", "Borderless fullscreen", "Fullscreen"]
## Resolutions offered (ones bigger than the screen are hidden).
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]

## Multiplier on BASE_MOUSE_SENSITIVITY. Change with set_mouse_sensitivity().
var mouse_sensitivity := 1.0
## Change with set_display().
var window_mode := WindowMode.BORDERLESS
## Window size in windowed mode; in the fullscreen modes, the resolution the
## 3D world is rendered at. Change with set_display().
var resolution := Vector2i(1920, 1080)


func _ready() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Missing on first run; defaults are used then.
	mouse_sensitivity = clampf(config.get_value("controls", "mouse_sensitivity", 1.0),
			MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)
	window_mode = clampi(config.get_value("display", "window_mode", WindowMode.BORDERLESS),
			0, WindowMode.size() - 1) as WindowMode
	resolution = config.get_value("display", "resolution", _default_resolution())
	_apply_display.call_deferred() # The window must exist before it can be resized.


## Radians to turn per pixel of mouse movement.
func get_look_speed() -> float:
	return BASE_MOUSE_SENSITIVITY * mouse_sensitivity


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)
	_save("controls", "mouse_sensitivity", mouse_sensitivity)


## Sets and saves the display mode and resolution together, then applies them
## a moment later (outside whatever input event triggered this).
func set_display(mode: WindowMode, size: Vector2i) -> void:
	window_mode = mode
	resolution = size
	_save("display", "window_mode", window_mode)
	_save("display", "resolution", resolution)
	_apply_display.call_deferred()


## Resolutions that fit on the current screen, smallest first. Always
## includes the current resolution.
func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var fitting: Array[Vector2i] = []
	for size in RESOLUTIONS:
		if size.x <= screen.x and size.y <= screen.y:
			fitting.append(size)
	if not fitting.has(resolution):
		fitting.append(resolution)
		fitting.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	return fitting


func _apply_display() -> void:
	if Engine.is_embedded_in_editor():
		# The editor's Game tab can't change window mode or size. The choice
		# is still saved and applies when the game runs in its own window.
		changed.emit()
		return
	print("[Settings] Applying display: %s at %s" % [WINDOW_MODE_NAMES[window_mode], resolution])
	match window_mode:
		WindowMode.WINDOWED:
			# The window itself is the resolution, rendered at full detail.
			_set_render_scale(1.0)
			_set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_size_window()
		WindowMode.BORDERLESS, WindowMode.FULLSCREEN:
			# The window covers the screen, so the resolution sets how sharply
			# the 3D world is rendered; menus and the HUD stay sharp.
			_set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN \
					if window_mode == WindowMode.BORDERLESS \
					else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
			_set_render_scale(clampf(float(resolution.y) / screen.y, 0.25, 1.0))
	print("[Settings] Display applied.")
	changed.emit()


## Only touches the window if the mode actually changes.
func _set_window_mode(mode: DisplayServer.WindowMode) -> void:
	if DisplayServer.window_get_mode() == mode:
		return
	print("[Settings] Window mode %d -> %d" % [DisplayServer.window_get_mode(), mode])
	DisplayServer.window_set_mode(mode)


## Only touches the 3D render scale if it actually changes.
func _set_render_scale(scale: float) -> void:
	var root := get_tree().root
	if is_equal_approx(root.scaling_3d_scale, scale):
		return
	print("[Settings] 3D render scale %.2f -> %.2f" % [root.scaling_3d_scale, scale])
	root.scaling_3d_scale = scale


## Resizes and centers the window. Waits for the switch out of fullscreen to
## finish first, or the OS can restore the old size over ours.
func _size_window() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if window_mode != WindowMode.WINDOWED:
		return # Changed again while waiting.
	_set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED) # E.g. un-maximize.
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var size := resolution.min(screen_size)
	print("[Settings] Window size %s -> %s" % [DisplayServer.window_get_size(), size])
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + (screen_size - size) / 2)


## The largest offered resolution that fits the screen with room for the
## taskbar and title bar.
func _default_resolution() -> Vector2i:
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var best := RESOLUTIONS[0]
	for size in RESOLUTIONS:
		if size.x < screen.x and size.y < screen.y:
			best = size
	return best


func _save(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # Keep the other saved settings.
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)
	changed.emit()
