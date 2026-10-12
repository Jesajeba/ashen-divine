extends Area3D
## Flying bolt fired by enemies. Travels straight; damages the player
## (via take_hit) on contact and vanishes on hitting anything else.

@export var speed := 14.0
@export var lifetime := 4.0

var _direction := Vector3.FORWARD
var _damage := 0.0
var _knockback := 0.0
var _shooter: Node
var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(direction: Vector3, damage: float, knockback: float, shooter: Node) -> void:
	_direction = direction
	_damage = damage
	_knockback = knockback
	_shooter = shooter


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == _shooter:
		return
	if body.is_in_group("player") and body.has_method("take_hit"):
		var push := Vector3(_direction.x, 0.0, _direction.z).normalized() * _knockback
		body.take_hit(roundi(_damage), push)
	elif body is CharacterBody3D:
		return # Fly past other enemies.
	else:
		Vfx.sparks(global_position, -_direction) # Burst against the wall or floor.
	queue_free()
