class_name Pistol
extends Node3D
## Single-shot flintlock held in the off hand. Call fire() to shoot.
## The hammer falls, the charge ignites a moment later, and the shot is a
## hitscan from the active camera through the screen center. The pistol then
## reloads automatically before it can fire again.
##
## A body with a try_parry() method that returns true is parried instead of
## damaged. Otherwise, bodies with a take_hit(damage, impulse) method are
## damaged and other RigidBody3Ds are pushed at the point of impact.

## Emitted at the moment the shot goes off.
signal fired
## Emitted when the shot parries an attack.
signal parried
## Emitted when the shot hits something that takes damage or parries.
signal target_hit

@export var damage := 3
@export var knockback := 12.0 ## Impulse applied to hit bodies.
@export var max_range := 60.0
@export var ignition_delay := 0.08 ## Delay between the hammer falling and the shot.
@export var reload_time := 2.5 ## Time spent lowered, between recoil and raising again.
@export var stamina_cost := 15.0
## Health spent per shot. It stays reclaimable (see Health) and won't be
## spent if it would be fatal.
@export var health_cost := 10.0

## Set by the wielder. Without them, firing is free.
var stamina: Stamina
var health: Health

@onready var pivot: Node3D = $Pivot
@onready var hammer: Node3D = $Pivot/Hammer
@onready var muzzle_light: OmniLight3D = $Pivot/Muzzle/Light
@onready var muzzle_flash: MeshInstance3D = $Pivot/Muzzle/Flash
@onready var smoke: GPUParticles3D = $Pivot/Muzzle/Smoke

var _rest_position: Vector3
var _rest_rotation: Vector3
var _hammer_cocked: Vector3
var _loaded := true
var _wielder: CollisionObject3D


func _ready() -> void:
	_rest_position = pivot.position
	_rest_rotation = pivot.rotation
	_hammer_cocked = hammer.rotation
	_wielder = _find_wielder()


func fire() -> void:
	if not _loaded:
		return
	if health and health.value <= health_cost:
		health.spend(health_cost) # Refused; this just flags it on the HP bar.
		return
	if stamina and not stamina.try_spend(stamina_cost):
		return
	if health:
		health.spend(health_cost)
	_loaded = false

	var recoil_rotation := _rest_rotation + Vector3(deg_to_rad(30.0), 0.0, 0.0)
	var recoil_position := _rest_position + Vector3(0.0, 0.02, 0.1)
	var lowered_rotation := _rest_rotation + Vector3(deg_to_rad(-60.0), 0.0, 0.0)
	var lowered_position := _rest_position + Vector3(0.0, -0.2, 0.1)

	# Physics process mode, since the shot queries the physics space.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Hammer falls, then the charge ignites.
	tween.tween_property(hammer, "rotation", _hammer_cocked + Vector3(deg_to_rad(-50.0), 0.0, 0.0), 0.03)
	tween.tween_interval(ignition_delay)
	tween.tween_callback(_discharge)
	# Recoil kick, then settle.
	tween.tween_property(pivot, "rotation", recoil_rotation, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "position", recoil_position, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation", _rest_rotation, 0.25)
	tween.parallel().tween_property(pivot, "position", _rest_position, 0.25)
	# Lower out of view to reload, re-cock, and raise again.
	tween.tween_property(pivot, "rotation", lowered_rotation, 0.3)
	tween.parallel().tween_property(pivot, "position", lowered_position, 0.3)
	tween.tween_interval(reload_time)
	tween.tween_callback(func() -> void: hammer.rotation = _hammer_cocked)
	tween.tween_property(pivot, "rotation", _rest_rotation, 0.3)
	tween.parallel().tween_property(pivot, "position", _rest_position, 0.3)
	tween.tween_callback(func() -> void: _loaded = true)


func _discharge() -> void:
	muzzle_flash.visible = true
	muzzle_light.visible = true
	get_tree().create_timer(0.05).timeout.connect(_hide_flash)
	smoke.restart()
	Audio.play("gunshot")
	fired.emit()

	# Aim from the camera so shots land on the crosshair wherever the pistol is held.
	var camera := get_viewport().get_camera_3d()
	var from := camera.global_position
	var to := from - camera.global_basis.z * max_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if _wielder:
		query.exclude = [_wielder.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var body: Object = hit.collider
	var impulse := (to - from).normalized() * knockback
	if body.has_method("try_parry") and body.try_parry():
		parried.emit() # A parry deals no damage; it opens the target up instead.
		target_hit.emit()
	elif body.has_method("take_hit"):
		body.take_hit(damage, impulse)
		target_hit.emit()
	else:
		Vfx.sparks(hit.position, hit.normal)
		if body is RigidBody3D:
			body.apply_impulse(impulse, hit.position - body.global_position)


func _hide_flash() -> void:
	muzzle_flash.visible = false
	muzzle_light.visible = false


func _find_wielder() -> CollisionObject3D:
	var node := get_parent()
	while node and not node is CollisionObject3D:
		node = node.get_parent()
	return node
