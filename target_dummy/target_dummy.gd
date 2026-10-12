extends RigidBody3D
## Practice target. Flashes and gets knocked back when hit; breaks after
## max_health hits.

@export var max_health := 3

@onready var mesh: MeshInstance3D = $MeshInstance3D

var health: int
var _material: StandardMaterial3D
var _base_color: Color


func _ready() -> void:
	health = max_health
	# Own copy of the material so each dummy flashes independently.
	_material = mesh.get_active_material(0).duplicate()
	mesh.material_override = _material
	_base_color = _material.albedo_color


func take_hit(damage: int, impulse: Vector3) -> void:
	if health <= 0:
		return
	health -= damage
	apply_central_impulse(impulse + Vector3.UP * impulse.length() * 0.3)

	_material.albedo_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", _base_color, 0.25)
	if health <= 0:
		tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.2)
		tween.tween_callback(queue_free)
