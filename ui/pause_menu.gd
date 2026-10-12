extends CanvasLayer
## Pause menu, toggled with Esc (ui_cancel). Pauses the game, frees the mouse,
## and offers resume, master volume, mouse sensitivity, return to the main
## menu, and quit. Runs
## while the tree is paused.

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var quit_button: Button = %QuitButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue


func _ready() -> void:
	visible = false
	volume_slider.value = roundf(Audio.master_volume * 100.0)
	_update_volume_label(volume_slider.value)
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value = Settings.mouse_sensitivity
	sensitivity_value.text = "%.2f" % Settings.mouse_sensitivity
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	resume_button.pressed.connect(close)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)
	sensitivity_value.text = "%.2f" % value


func _on_volume_changed(value: float) -> void:
	Audio.set_master_volume(value / 100.0)
	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	volume_value.text = "%d%%" % roundi(value)
