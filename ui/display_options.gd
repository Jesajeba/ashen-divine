extends VBoxContainer
## Display mode and resolution dropdowns with a Confirm button, wired to
## Settings. Used by both the main menu and the pause menu; each styles its
## own rows. Expects children ModeRow/ModeOption and
## ResolutionRow/ResolutionOption (OptionButtons) and ConfirmButton.
##
## Picking options only stages them; nothing changes until Confirm is pressed.
## Resolution is the window size when windowed, and the 3D render resolution
## in the fullscreen modes (see Settings).

@onready var mode_option: OptionButton = $ModeRow/ModeOption
@onready var resolution_option: OptionButton = $ResolutionRow/ResolutionOption
@onready var confirm_button: Button = $ConfirmButton

var _resolutions: Array[Vector2i] = []
var _pending_mode: int
var _pending_resolution: Vector2i


func _ready() -> void:
	for mode_name in Settings.WINDOW_MODE_NAMES:
		mode_option.add_item(mode_name)
	mode_option.item_selected.connect(_on_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	if Engine.is_embedded_in_editor():
		confirm_button.tooltip_text = "Running inside the editor: display changes apply when the game runs in its own window."
	_reset_to_current()


## Shows the settings currently in effect, discarding anything staged.
func _reset_to_current() -> void:
	_pending_mode = Settings.window_mode
	_pending_resolution = Settings.resolution
	mode_option.select(_pending_mode)
	resolution_option.clear()
	_resolutions = Settings.available_resolutions()
	for size in _resolutions:
		resolution_option.add_item("%d × %d" % [size.x, size.y])
	resolution_option.select(_resolutions.find(_pending_resolution))
	_refresh()


func _refresh() -> void:
	resolution_option.tooltip_text = "The window size." \
			if _pending_mode == Settings.WindowMode.WINDOWED \
			else "The resolution the world is rendered at. Lower is faster; menus stay sharp."
	confirm_button.disabled = _pending_mode == Settings.window_mode \
			and _pending_resolution == Settings.resolution


func _on_mode_selected(index: int) -> void:
	_pending_mode = index
	_refresh()


func _on_resolution_selected(index: int) -> void:
	_pending_resolution = _resolutions[index]
	_refresh()


func _on_confirm_pressed() -> void:
	Settings.set_display(_pending_mode as Settings.WindowMode, _pending_resolution)
	confirm_button.disabled = true
	# Re-list once applied, in case the window ended up on another screen.
	# (A connection rather than await, so it's dropped if this menu closes.)
	get_tree().create_timer(0.3, true).timeout.connect(_reset_to_current)
