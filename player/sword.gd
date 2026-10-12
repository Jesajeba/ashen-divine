class_name Sword
extends Node3D
## Rapier held in first-person view. Call press() and release() with the
## attack button.
##
## A quick click performs the next move in a three-hit combo: slash
## right-to-left, slash left-to-right, thrust. Each move has a deliberate
## windup, strike and follow-through, and costs stamina. Clicking during a move
## buffers the next one. After a slash there's a short grace window to continue
## the combo; miss it and the combo starts over. The thrust is the finisher and
## must fully recover before attacking again.
##
## Holding the button charges a heavy thrust instead. Releasing it lunges the
## wielder forward (via lunge_requested) and strikes harder the longer it was
## charged.
##
## Bodies inside the move's hitbox when it lands get hit: those with a
## take_hit(damage, impulse) method are damaged, other RigidBody3Ds are pushed.

## Emitted when a heavy thrust is released; the wielder should move forward
## by distance over duration seconds.
signal lunge_requested(distance: float, duration: float)
## Emitted when a strike connects with something. impact is 0 to 1;
## damage_dealt is the total damage done to bodies that take damage.
signal hit_landed(impact: float, damage_dealt: int)

@export var damage := 1
@export var knockback := 8.0 ## Impulse applied to hit bodies.
@export var recover_time := 0.45
@export var combo_grace := 0.35 ## Extra time after recovering to continue the combo.

@export_group("Blood Coating")
@export var blood_per_hit := 0.1 ## Coating added per point of impact (0-1) of a landed hit, plus a base amount.
@export var blood_max := 0.85 ## Most of the blade that can be covered (0-1).
@export var blood_dry_rate := 0.004 ## Coating lost per second as it dries off.

@export_group("Heavy Thrust")
@export var hold_threshold := 0.25 ## Hold longer than this to charge instead of a light attack.
@export var charge_time := 1.2 ## Time to reach full charge.
@export var heavy_cost := 35.0
@export var heavy_damage_min := 2
@export var heavy_damage_max := 5
@export var heavy_knockback := 16.0 ## Impulse at full charge; half at no charge.
@export var lunge_distance_min := 0.6
@export var lunge_distance_max := 2.2

## Poses are the pivot's position and rotation (degrees) in camera space.
## "push" is the local knockback direction, scaled by knockback.
## "impact" (0 to 1) drives hit-stop and camera shake when the move connects.
const COMBO := [
	{ # Slash right to left.
		"windup_pos": Vector3(0.38, -0.16, -0.3), "windup_rot": Vector3(-5, 15, -80),
		"strike_pos": Vector3(-0.25, -0.22, -0.4), "strike_rot": Vector3(-10, 160, -80),
		"windup_time": 0.3, "strike_time": 0.2, "follow_through": 0.1,
		"hitbox": "SlashHitbox", "damage_mult": 1, "push": Vector3(-0.7, 0.0, -0.7),
		"cost": 18.0, "impact": 0.25,
	},
	{ # Slash left to right.
		"windup_pos": Vector3(-0.38, -0.14, -0.28), "windup_rot": Vector3(-5, 175, -80),
		"strike_pos": Vector3(0.35, -0.22, -0.4), "strike_rot": Vector3(-10, 15, -80),
		"windup_time": 0.26, "strike_time": 0.2, "follow_through": 0.1,
		"hitbox": "SlashHitbox", "damage_mult": 1, "push": Vector3(0.7, 0.0, -0.7),
		"cost": 18.0, "impact": 0.25,
	},
	{ # Thrust.
		"windup_pos": Vector3(0.2, -0.23, -0.05), "windup_rot": Vector3(-85, 8, 0),
		"strike_pos": Vector3(0.12, -0.18, -0.8), "strike_rot": Vector3(-85, 8, 0),
		"windup_time": 0.34, "strike_time": 0.16, "follow_through": 0.14,
		"hitbox": "ThrustHitbox", "damage_mult": 2, "push": Vector3(0.0, 0.0, -1.5),
		"cost": 24.0, "impact": 0.45,
	},
]

const HEAVY_ROT := Vector3(-85, 8, 0)
const HEAVY_CHARGE_START_POS := Vector3(0.18, -0.22, -0.15) ## Drawn back as charging begins...
const HEAVY_CHARGE_FULL_POS := Vector3(0.24, -0.26, -0.02) ## ...and further back at full charge.
const HEAVY_STRIKE_POS := Vector3(0.1, -0.17, -0.95)
const HEAVY_STRIKE_TIME := 0.2 ## Also the lunge duration, so the thrust lands as the lunge ends.

## Set by the wielder. Without one, attacks are free.
var stamina: Stamina

## Drawn over the blade and cup. Blood shows where a noise pattern falls under
## the coverage, so it spreads in blotches as coverage grows.
const BLOOD_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;

uniform sampler2D noise_tex : hint_default_white, repeat_enable;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 blood_color : source_color = vec4(0.32, 0.01, 0.01, 1.0);

void fragment() {
	float n = texture(noise_tex, UV * vec2(2.0, 5.0)).r;
	float mask = smoothstep(1.0 - coverage, 1.0 - coverage + 0.06, n);
	ALBEDO = blood_color.rgb * (0.65 + 0.35 * n);
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
	ALPHA = mask * blood_color.a;
}
"""

@onready var pivot: Node3D = $Pivot

var _rest_position: Vector3
var _rest_rotation: Vector3
var _blood := 0.0 ## How much of the blade is coated, 0 to 1.
var _blood_material: ShaderMaterial
var _step := 0
var _busy := false
var _committed := false
var _queued := false
var _combo_expires_at := 0.0
var _tween: Tween
var _held := false
var _held_time := 0.0
var _charging := false
var _charge := 0.0 ## 0 to 1.


func _ready() -> void:
	_rest_position = pivot.position
	_rest_rotation = pivot.rotation
	_setup_blood_coating()


func _setup_blood_coating() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.06
	noise.fractal_octaves = 2
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 128
	texture.height = 128

	var shader := Shader.new()
	shader.code = BLOOD_SHADER
	_blood_material = ShaderMaterial.new()
	_blood_material.shader = shader
	_blood_material.set_shader_parameter("noise_tex", texture)
	_blood_material.set_shader_parameter("coverage", 0.0)
	for part_name in ["Blade", "Cup"]:
		var part := pivot.get_node_or_null(part_name) as GeometryInstance3D
		if part:
			part.material_overlay = _blood_material


## Adds blood to the blade for a hit of the given impact (0 to 1).
func add_blood(impact: float) -> void:
	_blood = minf(_blood + blood_per_hit * (0.5 + impact), blood_max)


func _process(delta: float) -> void:
	if _blood > 0.0:
		_blood = maxf(_blood - blood_dry_rate * delta, 0.0)
		_blood_material.set_shader_parameter("coverage", _blood)
	if _held:
		_held_time += delta
		# Charging waits for any move in progress to finish.
		if not _charging and not _busy and _held_time >= hold_threshold \
				and (not stamina or stamina.has_any()):
			_begin_charge()
	if _charging:
		_charge = minf(_charge + delta / charge_time, 1.0)
		if stamina:
			stamina.hold_regen()


## True while attacking or charging; the wielder should move slowly.
func is_attacking() -> bool:
	return _busy or _charging


## True during a windup or strike, which can't be cancelled (e.g. by dashing).
func is_committed() -> bool:
	return _committed


func press() -> void:
	_held = true
	_held_time = 0.0


func release() -> void:
	if not _held:
		return # The press was used for something else, e.g. capturing the mouse.
	_held = false
	if _charging:
		_release_heavy()
	else:
		attack()


## Abandons a heavy thrust being charged, without striking or spending stamina.
## The button must be pressed again to attack.
func cancel_charge() -> void:
	if not _charging:
		return
	_charging = false
	_held = false
	_step = 0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(pivot, "position", _rest_position, recover_time)
	_tween.parallel().tween_property(pivot, "rotation", _rest_rotation, recover_time)
	_tween.tween_callback(_on_locked_recovery_finished)


## Performs (or buffers) the next light attack in the combo.
func attack() -> void:
	if _busy:
		_queued = true
		return
	if _now() > _combo_expires_at:
		_step = 0
	if _try_spend(COMBO[_step].cost):
		_start_move()


func _start_move() -> void:
	var move: Dictionary = COMBO[_step]
	_busy = true
	_committed = true
	_queued = false
	if _tween:
		_tween.kill()

	var strike_time: float = move.strike_time
	var impulse: Vector3 = move.push * knockback
	_tween = create_tween()
	# Slow, deliberate windup; the strike accelerates through its arc.
	_tween.tween_property(pivot, "position", move.windup_pos, move.windup_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(pivot, "rotation", _deg(move.windup_rot), move.windup_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(Audio.play.bind("sword_swoosh"))
	_tween.tween_property(pivot, "position", move.strike_pos, strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(pivot, "rotation", _deg(move.strike_rot), strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_callback(
			_apply_hits.bind(get_node(move.hitbox), damage * move.damage_mult, impulse, move.impact)
	).set_delay(strike_time * 0.6)
	_tween.tween_interval(move.follow_through)
	_tween.tween_callback(_on_strike_finished)


func _on_strike_finished() -> void:
	_committed = false
	_step = (_step + 1) % COMBO.size()
	var finished_combo := _step == 0
	if _queued and not finished_combo and _try_spend(COMBO[_step].cost):
		_start_move() # Flow straight into the buffered next move.
		return
	_queued = false

	# Slashes can be followed up during recovery; the finisher locks until done.
	_busy = finished_combo
	_combo_expires_at = _now() + recover_time + combo_grace
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(pivot, "position", _rest_position, recover_time)
	_tween.parallel().tween_property(pivot, "rotation", _rest_rotation, recover_time)
	if finished_combo:
		_tween.tween_callback(_on_locked_recovery_finished)


func _on_locked_recovery_finished() -> void:
	_busy = false
	_committed = false
	if _queued:
		_queued = false
		attack()


func _begin_charge() -> void:
	_charging = true
	_charge = 0.0
	_busy = true
	_queued = false
	if _tween:
		_tween.kill()

	# Aim the point forward, then keep drawing back as the charge builds.
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(pivot, "position", HEAVY_CHARGE_START_POS, 0.25)
	_tween.parallel().tween_property(pivot, "rotation", _deg(HEAVY_ROT), 0.25)
	_tween.tween_property(pivot, "position", HEAVY_CHARGE_FULL_POS, maxf(charge_time - 0.25, 0.05))


func _release_heavy() -> void:
	var charge := _charge
	_charging = false
	_step = 0 # A heavy thrust resets the combo.
	if _tween:
		_tween.kill()

	if not _try_spend(heavy_cost):
		# Out of stamina: lower the sword without striking.
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(pivot, "position", _rest_position, recover_time)
		_tween.parallel().tween_property(pivot, "rotation", _rest_rotation, recover_time)
		_tween.tween_callback(_on_locked_recovery_finished)
		return

	_committed = true
	var damage_amount := roundi(lerpf(heavy_damage_min, heavy_damage_max, charge))
	var impulse := Vector3.FORWARD * heavy_knockback * lerpf(0.5, 1.0, charge)
	lunge_requested.emit(lerpf(lunge_distance_min, lunge_distance_max, charge), HEAVY_STRIKE_TIME)
	Audio.play("heavy_swoosh")

	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(pivot, "position", HEAVY_STRIKE_POS, HEAVY_STRIKE_TIME).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_apply_hits.bind($ThrustHitbox, damage_amount, impulse, lerpf(0.6, 1.0, charge)))
	_tween.tween_interval(0.25)
	_tween.tween_callback(func() -> void: _committed = false)
	_tween.tween_property(pivot, "position", _rest_position, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(pivot, "rotation", _rest_rotation, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_locked_recovery_finished)


## local_impulse is in this node's space (-Z is where the camera looks).
func _apply_hits(hitbox: Area3D, damage_amount: int, local_impulse: Vector3, impact: float) -> void:
	var impulse := global_basis * local_impulse
	var hit_any := false
	var damage_dealt := 0
	for body in hitbox.get_overlapping_bodies():
		if body.is_ancestor_of(self):
			continue # Don't hit whoever is holding the sword.
		if body.has_method("take_hit"):
			# take_hit may report the damage actually dealt (e.g. a critical).
			var dealt: Variant = body.take_hit(damage_amount, impulse)
			damage_dealt += dealt if dealt is int else damage_amount
			hit_any = true
		elif body is RigidBody3D:
			body.apply_central_impulse(impulse)
			hit_any = true
	if hit_any:
		hit_landed.emit(impact, damage_dealt)
		if damage_dealt > 0:
			add_blood(impact)


func _try_spend(cost: float) -> bool:
	return not stamina or stamina.try_spend(cost)


static func _deg(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
