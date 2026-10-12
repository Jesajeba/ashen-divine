extends Node3D
## Orb that flies to a point on the ground and explodes there, damaging the
## player if they're within radius. A glowing ring marks the landing spot from
## the moment it's fired, so it can be seen coming and dodged (dodge
## invincibility also works). Passes through everything on the way.

@export var speed := 9.0
@export var radius := 2.2
@export var marker_color := Color(0.3, 1.0, 0.35, 0.35)
@export var explosion_color := Color(0.4, 1.0, 0.4, 0.6)

var _target: Vector3
var _damage := 0.0
var _knockback := 0.0
var _marker: MeshInstance3D


func launch(target: Vector3, damage: float, knockback: float) -> void:
	_target = target
	_damage = damage
	_knockback = knockback
	_marker = _make_disc(marker_color)
	get_parent().add_child(_marker)
	_marker.global_position = _target + Vector3.UP * 0.05
	# Pulse the marker so it reads as a warning.
	var tween := _marker.create_tween().set_loops()
	tween.tween_property(_marker, "scale", Vector3(0.85, 1.0, 0.85), 0.25)
	tween.tween_property(_marker, "scale", Vector3.ONE, 0.25)


func _physics_process(delta: float) -> void:
	var to_target := _target - global_position
	var step := speed * delta
	if to_target.length() <= step:
		_explode()
		return
	global_position += to_target.normalized() * step


func _explode() -> void:
	Audio.play_at("orb_explosion", _target)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.has_method("take_hit"):
		var offset := player.global_position - _target
		if Vector2(offset.x, offset.z).length() <= radius and absf(offset.y) < 2.0:
			var push := Vector3(offset.x, 0.0, offset.z).normalized() * _knockback
			player.take_hit(roundi(_damage), push)

	# A quick expanding flash, then clean up.
	var flash := _make_disc(explosion_color)
	get_parent().add_child(flash)
	flash.global_position = _target + Vector3.UP * 0.1
	flash.scale = Vector3(0.3, 1.0, 0.3)
	var material: StandardMaterial3D = (flash.mesh as CylinderMesh).material
	var tween := flash.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3(1.0, 8.0, 1.0), 0.25)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)

	if is_instance_valid(_marker):
		_marker.queue_free()
	queue_free()


func _make_disc(color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.material = material
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc
