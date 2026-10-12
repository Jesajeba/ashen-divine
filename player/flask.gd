class_name Flask
extends Node3D
## Healing flask with a limited number of charges. Call use() to drink:
## the flask is raised to the mouth, drank emits partway through (the wielder
## applies the healing then), and it's lowered out of view again.

signal drank
signal finished
signal charges_changed(charges: int)

@export var max_charges := 3
@export var heal_fraction := 0.5 ## Fraction of max health restored per drink.
@export var raise_time := 0.35
@export var drink_time := 0.45 ## Time at the mouth; healing applies at the end of it.
@export var lower_time := 0.3

@onready var pivot: Node3D = $Pivot

var charges: int

var _using := false
var _hidden_position: Vector3
var _hidden_rotation: Vector3

const DRINK_POS := Vector3(-0.02, -0.12, -0.28)
const DRINK_ROT := Vector3(65, 0, -10) ## Degrees; tips the top toward the camera.


func _ready() -> void:
	charges = max_charges
	_hidden_position = pivot.position
	_hidden_rotation = pivot.rotation
	pivot.visible = false


func is_using() -> bool:
	return _using


## Starts drinking if a charge is left. Returns whether it started.
func use() -> bool:
	if _using or charges <= 0:
		return false
	_using = true
	charges -= 1
	charges_changed.emit(charges)
	Audio.play("potion_drink")

	var drink_rot := Vector3(deg_to_rad(DRINK_ROT.x), deg_to_rad(DRINK_ROT.y), deg_to_rad(DRINK_ROT.z))
	pivot.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "position", DRINK_POS, raise_time).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "rotation", drink_rot, raise_time).set_ease(Tween.EASE_OUT)
	tween.tween_interval(drink_time)
	tween.tween_callback(drank.emit)
	tween.tween_property(pivot, "position", _hidden_position, lower_time).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(pivot, "rotation", _hidden_rotation, lower_time).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_finished)
	return true


func _on_finished() -> void:
	pivot.visible = false
	_using = false
	finished.emit()
