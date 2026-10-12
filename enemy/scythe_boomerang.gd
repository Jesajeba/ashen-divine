extends Area3D
## The reaper's thrown scythe. Spins out to a point past where the player
## stood, then flies back to the thrower's hand. It can hit the player once on
## the way out and once on the way back, and passes through walls.

@export var out_time := 0.7 ## Seconds to reach the far point.
@export var overshoot := 2.0 ## Meters past the target it flies.
@export var return_speed := 16.0
@export var spin_speed := 18.0 ## Radians per second.
@export var max_lifetime := 4.0 ## Gives up and returns to hand after this long.

@onready var visual: Node3D = $Visual

var _thrower: Node3D
var _start: Vector3
var _far_point: Vector3
var _damage := 0.0
var _knockback := 0.0
var _time := 0.0
var _returning := false
var _hit_this_pass := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(thrower: Node3D, target: Vector3, damage: float, knockback: float) -> void:
	_thrower = thrower
	_start = global_position
	var direction := (target - _start).normalized()
	_far_point = target + direction * overshoot
	_damage = damage
	_knockback = knockback


func _physics_process(delta: float) -> void:
	_time += delta
	visual.rotate_y(spin_speed * delta)

	if not is_instance_valid(_thrower) or _thrower.get("health") <= 0:
		queue_free() # The reaper is gone; drop the scythe.
		return

	if not _returning:
		var t := minf(_time / out_time, 1.0)
		global_position = _start.lerp(_far_point, 1.0 - pow(1.0 - t, 2.0)) # Decelerates outward.
		if t >= 1.0:
			_returning = true
			_hit_this_pass = false
			_check_overlaps() # Already inside the player when turning around.
		return

	var hand: Vector3 = _thrower.call("get_hand_position")
	var to_hand := hand - global_position
	var step := return_speed * delta
	if to_hand.length() <= step + 0.3 or _time > max_lifetime:
		_thrower.call("catch_scythe")
		queue_free()
		return
	global_position += to_hand.normalized() * step


func _on_body_entered(body: Node3D) -> void:
	_try_hit(body)


func _check_overlaps() -> void:
	for body in get_overlapping_bodies():
		_try_hit(body)


func _try_hit(body: Node3D) -> void:
	if _hit_this_pass or not body.is_in_group("player") or not body.has_method("take_hit"):
		return
	_hit_this_pass = true
	var travel := (_far_point - _start) if not _returning else (_start - _far_point)
	var push := Vector3(travel.x, 0.0, travel.z).normalized() * _knockback
	body.take_hit(roundi(_damage), push)
