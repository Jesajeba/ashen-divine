class_name Enemy
extends CharacterBody3D
## Melee enemy. Patrols around where it spawned, chases the player on sight,
## and attacks once in range. Patrolling and chasing follow the navigation mesh
## (via NavigationAgent3D) when the level has one.
##
## Every attack has its own readable stance, so players can tell what's coming:
## - Slash: upright, blade cocked out to its right. One wide sweep.
## - Overhead: stands tall leaning back, blade raised high. Slow, narrow, hits hard.
## - Combo: hunched forward, blade held low to its left. Three quick hits.
## - Dash thrust: only from mid range. Crouches low, blade aimed at the player,
##   then charges forward.
## Through each windup the blade and eyes glow brighter, and the blade glints
## just before the blow. The enemy tracks the player until the glint, steps in
## to close the gap as it strikes, then commits to that direction.
## Normal hits don't interrupt its attacks.
##
## Shooting it (try_parry) while a blow is in motion, after it's launched but
## before it lands, parries it; the glint is the cue to pull the trigger. A
## parried enemy staggers for a while and takes extra damage from every hit
## until it recovers.
##
## It sometimes dodges away when the player starts a sword attack nearby, and
## circles the player while waiting to attack again.

signal died

enum State { PATROL, CHASE, ATTACK, DODGE, STAGGER, DEAD }

@export var max_health := 12
@export var walk_speed := 1.8
@export var chase_speed := 3.6
@export var acceleration := 8.0
@export var turn_speed := 5.0 ## Radians per second.

@export_group("Senses")
@export var eye_height := 1.6 ## Height above its origin that it sees from.
@export var sight_range := 14.0
@export var sight_angle := 120.0 ## Field of view in degrees.
@export var hearing_range := 4.0 ## Notices the player this close regardless of facing.
@export var lose_interest_time := 4.0 ## Seconds without seeing the player before giving up.

@export_group("Patrol")
@export var patrol_radius := 7.0
@export var patrol_wait_min := 1.0
@export var patrol_wait_max := 3.0

@export_group("Combat")
@export var attack_cooldown_min := 1.2
@export var attack_cooldown_max := 2.4
@export var windup_turn_speed := 8.0 ## Radians per second while tracking the player in a windup.
@export var dash_strike_turn_speed := 1.5 ## Radians per second a dashing strike can steer mid-charge.
@export var strike_stop_distance := 1.2 ## Strikes step in to about this far from the player.
@export var engage_range := 4.0 ## In sight and this close, it squares up to the player instead of pathing.
@export var strafe_speed := 1.4 ## Circling speed while waiting to attack.
@export var projectile_scene: PackedScene ## Fired by hits marked "projectile".
@export var dodge_chance := 0.35 ## Chance to dodge when the player starts a sword attack nearby.
@export var dodge_speed := 7.0
@export var dodge_duration := 0.3
@export var dodge_cooldown := 2.5

@export_group("Stagger")
@export var stagger_time := 1.6
@export var stagger_damage_multiplier := 3.0

@export_group("Model")
@export var rest_rotation := Vector3(-120, 0, 0) ## WeaponPivot rotation (degrees) when idle.
@export var stagger_rotation := Vector3(-170, 0, 0) ## WeaponPivot rotation (degrees) when staggered.
@export var death_rotation := Vector3(90, 0, 0) ## Model rotation (degrees) it falls to on death.
@export var glow_mesh: NodePath = ^"Model/WeaponPivot/Blade" ## Glows through attack windups.
@export var eye_mesh: NodePath = ^"Model/EyeL" ## Its material's glow also builds in windups.
@export var glow_energy := 0.6 ## A small light in its eye color, so it's visible in the dark. 0 disables it.
@export var glow_range := 3.5

## Each attack has a stance ("lean" in degrees, positive leans back, and
## "crouch" in meters) held for the whole attack, the distance range it's used
## from, an optional cooldown of its own, and one or more hits.
##
## Each hit: weapon poses are the WeaponPivot's rotation in degrees (the blade
## points along the pivot's +Y; the enemy faces -Z). "creep" is how fast it
## advances during the windup, "step" the fastest it moves to close in during
## the strike. The blow lands on the player within "reach" meters and "arc"
## degrees of straight ahead. "dash" hits track the player for the whole
## windup, steer slightly mid-charge, and land on first contact during the
## strike instead of at its end. Optional "backstep_speed"/"backstep_time"
## leap backwards at the start of the windup, and "hop" adds an upward kick. "projectile" hits instead fire projectile_scene
## from the glint at the end of the strike ("reach" is then unused), "spread"
## of them fanned "spread_angle" degrees apart if given. Subclasses can handle
## their own hit types in _resolve_special_hit().
##
## Subclasses supply their own list by overriding _get_attacks().
const ATTACKS := [
	{
		"name": "slash", "min_range": 0.0, "max_range": 2.8, "cooldown": 0.0,
		"lean": 0.0, "crouch": 0.0, "recover": 0.7,
		"hits": [
			{ "windup": 0.8, "windup_rot": Vector3(0, -40, -80), "strike_rot": Vector3(0, 160, -80),
				"strike": 0.2, "creep": 0.8, "step": 8.0, "reach": 2.4, "arc": 75.0,
				"damage": 20, "knockback": 4.0 },
		],
	},
	{
		"name": "overhead", "min_range": 0.0, "max_range": 2.8, "cooldown": 0.0,
		"lean": 10.0, "crouch": 0.05, "recover": 0.9,
		"hits": [
			{ "windup": 1.2, "windup_rot": Vector3(30, 0, 0), "strike_rot": Vector3(-110, 0, 0),
				"strike": 0.18, "creep": 0.6, "step": 9.0, "reach": 2.5, "arc": 35.0,
				"damage": 35, "knockback": 7.0 },
		],
	},
	{
		"name": "combo", "min_range": 0.0, "max_range": 2.6, "cooldown": 4.0,
		"lean": -14.0, "crouch": -0.05, "recover": 1.0,
		"hits": [
			{ "windup": 0.9, "windup_rot": Vector3(0, 225, -80), "strike_rot": Vector3(0, 15, -80),
				"strike": 0.18, "creep": 0.8, "step": 7.0, "reach": 2.3, "arc": 70.0,
				"damage": 12, "knockback": 2.0 },
			{ "windup": 0.3, "windup_rot": Vector3(0, -40, -80), "strike_rot": Vector3(0, 160, -80),
				"strike": 0.18, "creep": 1.5, "step": 7.0, "reach": 2.3, "arc": 70.0,
				"damage": 12, "knockback": 2.0 },
			{ "windup": 0.45, "windup_rot": Vector3(30, 0, 0), "strike_rot": Vector3(-110, 0, 0),
				"strike": 0.18, "creep": 1.5, "step": 8.0, "reach": 2.4, "arc": 40.0,
				"damage": 18, "knockback": 6.0 },
		],
	},
	{
		"name": "dash", "min_range": 4.0, "max_range": 8.0, "cooldown": 6.0,
		"lean": -18.0, "crouch": -0.25, "recover": 1.1,
		"hits": [
			{ "windup": 0.9, "windup_rot": Vector3(-75, 0, 0), "strike_rot": Vector3(-95, 0, 0),
				"strike": 0.45, "creep": 0.0, "step": 15.0, "reach": 1.6, "arc": 70.0,
				"damage": 25, "knockback": 8.0, "dash": true },
		],
	},
]
const GLINT_LEAD := 0.3 ## The glint flashes this long before the strike.
const STAGGER_TINT := Color(1.0, 0.8, 0.3)
const HEALTH_FILL_WIDTH := 0.76

@onready var model: Node3D = $Model
@onready var weapon_pivot: Node3D = $Model/WeaponPivot
@onready var glint: MeshInstance3D = $Model/WeaponPivot/Glint
@onready var health_bar: Node3D = $HealthBar
@onready var health_fill: MeshInstance3D = $HealthBar/Fill
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int

var _state := State.PATROL
var _state_time := 0.0
var _player: Node3D
var _home: Vector3
var _patrol_target: Vector3
var _patrol_wait := 0.0
var _patrol_leg_time := 0.0
var _last_seen_at := -INF
var _last_known_pos: Vector3
var _attack: Dictionary
var _hit_index := 0
var _attack_phase := 0 ## 0 windup, 1 strike, 2 recover.
var _phase_time := 0.0
var _hit_resolved := false
var _strike_velocity := Vector3.ZERO
var _attack_cooldown := 0.0
var _attack_ready_at := {} ## Attack name -> time its own cooldown ends.
var _parryable := false
var _strafe_dir := 1.0
var _dodge_velocity := Vector3.ZERO
var _dodge_cooldown_left := 0.0
var _player_was_attacking := false
var _player_attack_started := false
var _pose_tween: Tween
var _stance_tween: Tween
var _glow_tween: Tween
var _flash_tween: Tween
var _body_mat: StandardMaterial3D
var _blade_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _body_color: Color
var _eye_energy: float
var _glow_light: OmniLight3D


func _ready() -> void:
	health = max_health
	_home = global_position
	_patrol_target = _home
	_patrol_wait = randf_range(patrol_wait_min, patrol_wait_max)
	weapon_pivot.rotation = _deg(rest_rotation)
	health_bar.visible = false

	_own_materials()
	_body_mat = $Model/Body.material_override
	_blade_mat = get_node(glow_mesh).material_override
	_eye_mat = get_node(eye_mesh).material_override
	_body_color = _body_mat.albedo_color
	_eye_energy = _eye_mat.emission_energy_multiplier

	if glow_energy > 0.0:
		_glow_light = OmniLight3D.new()
		_glow_light.light_color = _eye_mat.emission
		_glow_light.light_energy = glow_energy
		_glow_light.omni_range = glow_range
		_glow_light.light_volumetric_fog_energy = 0.5
		model.add_child(_glow_light)
		_glow_light.position = Vector3(0.0, eye_height, -0.4)


func _process(_delta: float) -> void:
	# Billboard the health bar toward the camera.
	var camera := get_viewport().get_camera_3d()
	if health_bar.visible and camera:
		health_bar.global_basis = camera.global_basis


func _physics_process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	_state_time += delta
	_attack_cooldown -= delta
	_dodge_cooldown_left -= delta

	var player_attacking: bool = _player != null and _player.has_method("is_attack_committed") \
			and _player.is_attack_committed()
	_player_attack_started = player_attacking and not _player_was_attacking
	_player_was_attacking = player_attacking

	var desired := Vector3.ZERO
	match _state:
		State.PATROL:
			desired = _tick_patrol(delta)
		State.CHASE:
			desired = _tick_chase(delta)
		State.ATTACK:
			desired = _tick_attack(delta)
		State.DODGE:
			desired = _tick_dodge()
		State.STAGGER:
			desired = _tick_stagger()

	if _state == State.DODGE or (_state == State.ATTACK and (_attack_phase == 1 or _is_backstepping())):
		# Dodges, backsteps and strikes move at exactly their set speed.
		velocity.x = desired.x
		velocity.z = desired.z
	else:
		var weight := 1.0 - exp(-acceleration * delta)
		velocity.x = lerpf(velocity.x, desired.x, weight)
		velocity.z = lerpf(velocity.z, desired.z, weight)
	if not _apply_custom_vertical(delta) and not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


## Override to take over vertical movement (e.g. flying). Return true when
## handled; gravity is skipped that frame.
func _apply_custom_vertical(_delta: float) -> bool:
	return false


## True while a hit with "backstep_speed" is still leaping back in its windup.
func _is_backstepping() -> bool:
	if _state != State.ATTACK or _attack_phase != 0:
		return false
	var hit: Dictionary = _attack.hits[_hit_index]
	return hit.has("backstep_speed") and _phase_time < float(hit.get("backstep_time", 0.0))


# --- Public ----------------------------------------------------------------

## Called by the pistol. Returns true if the shot parried an attack.
func try_parry() -> bool:
	if _state != State.ATTACK or not _parryable:
		return false
	Vfx.parry_flash(glint.global_position)
	_enter_stagger()
	return true


## Returns the damage actually dealt.
func take_hit(damage: int, impulse: Vector3) -> int:
	if _state == State.DEAD:
		return 0
	var critical := _state == State.STAGGER
	var amount := roundi(damage * (stagger_damage_multiplier if critical else 1.0))
	health -= amount
	_update_health_bar()
	if critical:
		_spawn_label("%d!" % amount, STAGGER_TINT, 72)
	else:
		_spawn_label(str(amount), Color.WHITE, 48)
	_flash_white()
	Audio.play_at("enemy_hit_critical" if critical else "enemy_hit", global_position + Vector3.UP)
	# Spray blood along the blow, a little upward.
	var spray := _flat(impulse).normalized() + Vector3.UP * 0.4
	Vfx.blood(_body_center(), spray, 2.0 if critical else 1.0)

	# Mid-attack it barely budges.
	velocity += _flat(impulse) * (0.15 if _state == State.ATTACK else 0.4)

	if health <= 0:
		_die()
	else:
		_notice_player()
	return amount


# --- States ----------------------------------------------------------------

func _tick_patrol(delta: float) -> Vector3:
	if _can_see_player():
		_notice_player()
		return Vector3.ZERO

	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		if _patrol_wait <= 0.0:
			_pick_patrol_target()
		return Vector3.ZERO

	var to_target := _flat(_patrol_target - global_position)
	_patrol_leg_time += delta
	# Give up on a leg after a while in case the target is unreachable.
	if to_target.length() < 0.5 or _patrol_leg_time > 15.0:
		_patrol_wait = randf_range(patrol_wait_min, patrol_wait_max)
		return Vector3.ZERO
	var move_dir := _path_direction(_patrol_target)
	_face_direction(move_dir, turn_speed, delta)
	return move_dir * walk_speed


func _tick_chase(delta: float) -> Vector3:
	var sees := _can_see_player()
	if sees:
		_last_seen_at = _now()
		_last_known_pos = _player.global_position
	elif _now() - _last_seen_at > lose_interest_time:
		_enter_patrol()
		return Vector3.ZERO

	var to_target := _flat(_last_known_pos - global_position)
	var dist := to_target.length()
	# Up close with a clear view, square up to the player; otherwise follow the path.
	var close := sees and dist < engage_range
	var move_dir := to_target.normalized() if close else _path_direction(_last_known_pos)
	_face_direction(to_target if close else move_dir, turn_speed, delta)

	if _player_attack_started and dist < 3.5 and _dodge_cooldown_left <= 0.0 \
			and randf() < dodge_chance:
		_enter_dodge(to_target)
		return Vector3.ZERO

	if sees and _attack_cooldown <= 0.0:
		var attack := _choose_attack(dist)
		if not attack.is_empty():
			_enter_attack(attack)
			return Vector3.ZERO

	return _engage_velocity(to_target, dist, sees, move_dir)


## Movement while chasing when not starting an attack or dodge. to_target
## points at where the player was last seen; move_dir is the way to walk there.
## Override for different spacing, e.g. keeping at range.
func _engage_velocity(to_target: Vector3, dist: float, sees: bool, move_dir: Vector3) -> Vector3:
	if sees and dist < engage_range and _attack_cooldown > 0.0:
		# Circle the player while waiting to attack, backing off if crowded.
		var side := to_target.normalized().cross(Vector3.UP) * _strafe_dir
		var back_off := -to_target.normalized() if dist < 1.6 else Vector3.ZERO
		return (side + back_off).normalized() * strafe_speed

	if dist < 0.5:
		return Vector3.ZERO # Reached where the player was last seen; look around.
	return move_dir * chase_speed


func _tick_attack(delta: float) -> Vector3:
	_phase_time += delta
	var hit: Dictionary = _attack.hits[_hit_index]
	var windup: float = hit.windup
	var to_player := _flat(_player.global_position - global_position) if _player else Vector3.ZERO

	match _attack_phase:
		0: # Windup: track the player until the glint, then commit.
			if _phase_time >= windup:
				_begin_strike(to_player)
				return _strike_velocity
			# Dashes keep tracking right up to the launch, so sidestepping
			# during the windup doesn't make them miss.
			var track_until := windup if hit.get("dash", false) else windup - GLINT_LEAD
			if _phase_time < track_until:
				_face_direction(to_player, windup_turn_speed, delta)
			if _is_backstepping():
				return global_basis.z * float(hit.backstep_speed)
			if to_player.length() > strike_stop_distance + 0.4:
				return -global_basis.z * float(hit.creep)
			return Vector3.ZERO

		1: # Strike.
			if hit.get("dash", false) and not _hit_resolved:
				if _player_in_reach(hit.reach, hit.arc):
					_resolve_hit()
					_strike_velocity = Vector3.ZERO # Stop on contact.
				elif _strike_velocity != Vector3.ZERO:
					# Steer the charge toward the player, but only a little.
					_face_direction(to_player, dash_strike_turn_speed, delta)
					_strike_velocity = -global_basis.z * _strike_velocity.length()
			if _phase_time >= hit.strike:
				if not _hit_resolved:
					_resolve_hit()
				if _hit_index + 1 < _attack.hits.size():
					_hit_index += 1
					_begin_windup()
				else:
					_begin_recover()
				return Vector3.ZERO
			return _strike_velocity

		_: # Recover.
			if _phase_time >= _attack.recover:
				_attack_cooldown = randf_range(attack_cooldown_min, attack_cooldown_max)
				_strafe_dir = [-1.0, 1.0].pick_random()
				_enter_chase()
			return Vector3.ZERO


func _tick_dodge() -> Vector3:
	if _state_time >= dodge_duration:
		_enter_chase()
		return Vector3.ZERO
	return _dodge_velocity


func _tick_stagger() -> Vector3:
	if _state_time >= stagger_time:
		_recover_from_stagger()
	return Vector3.ZERO


# --- Transitions -------------------------------------------------------------

func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _enter_patrol() -> void:
	_set_state(State.PATROL)
	_patrol_target = _home
	_patrol_leg_time = 0.0
	_patrol_wait = 0.0


func _enter_chase() -> void:
	_set_state(State.CHASE)


## Starts chasing (if not already busy) with the player's current position.
func _notice_player() -> void:
	if not _player:
		return
	_last_seen_at = _now()
	_last_known_pos = _player.global_position
	if _state == State.PATROL:
		_enter_chase()


## The attacks this enemy can use (see ATTACKS for the format).
func _get_attacks() -> Array:
	return ATTACKS


## Picks a random attack usable at this distance whose own cooldown is over.
func _choose_attack(dist: float) -> Dictionary:
	var options := []
	for attack: Dictionary in _get_attacks():
		if dist >= attack.min_range and dist <= attack.max_range \
				and _now() >= _attack_ready_at.get(attack.name, 0.0):
			options.append(attack)
	if options.is_empty():
		return {}
	return options.pick_random()


func _enter_attack(attack: Dictionary) -> void:
	_set_state(State.ATTACK)
	_attack = attack
	_hit_index = 0
	_attack_ready_at[attack.name] = _now() + float(attack.cooldown)

	# Take up the attack's stance; it's held until recovery.
	_kill_tween(_stance_tween)
	_stance_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_stance_tween.tween_property(model, "rotation:x", deg_to_rad(attack.lean), 0.3)
	_stance_tween.parallel().tween_property(model, "position:y", float(attack.crouch), 0.3)
	_begin_windup()


func _begin_windup() -> void:
	var hit: Dictionary = _attack.hits[_hit_index]
	var windup: float = hit.windup
	_attack_phase = 0
	_phase_time = 0.0
	_hit_resolved = false
	_parryable = false
	if hit.has("hop") and is_on_floor():
		velocity.y = float(hit.hop)

	# Raise the blade into the hit's windup pose and hold it there.
	_kill_tween(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(weapon_pivot, "rotation", _deg(hit.windup_rot), windup * 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# The glow builds through the windup, and the blade glints before the strike.
	_kill_tween(_glow_tween)
	_glow_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_glow_tween.tween_property(_blade_mat, "emission_energy_multiplier", 4.0, windup)
	_glow_tween.parallel().tween_property(_eye_mat, "emission_energy_multiplier", _eye_energy * 6.0, windup)
	_glow_tween.parallel().tween_callback(_flash_glint).set_delay(maxf(windup - GLINT_LEAD, 0.0))


func _begin_strike(to_player: Vector3) -> void:
	var hit: Dictionary = _attack.hits[_hit_index]
	var strike: float = hit.strike
	_attack_phase = 1
	_phase_time = 0.0
	_parryable = true # Only once the blow is launched, until it lands.
	if not hit.get("projectile", false) and not hit.get("aoe", false):
		Audio.play_at("enemy_swing", weapon_pivot.global_position)

	# Step in far enough to end up strike_stop_distance from the player.
	var gap := maxf(to_player.length() - strike_stop_distance, 0.0)
	_strike_velocity = -global_basis.z * minf(gap / strike, hit.step)

	_kill_tween(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(weapon_pivot, "rotation", _deg(hit.strike_rot), strike) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _resolve_hit() -> void:
	var hit: Dictionary = _attack.hits[_hit_index]
	_hit_resolved = true
	_parryable = false
	_fade_glow(0.2)
	if _resolve_special_hit(hit):
		pass
	elif hit.get("projectile", false):
		_fire_projectile(hit)
	elif _player and _player.has_method("take_hit") and _player_in_reach(hit.reach, hit.arc):
		var away := _flat(_player.global_position - global_position).normalized()
		_player.take_hit(hit.damage, away * float(hit.knockback))


## Override to give hits custom effects when they land. Return true if the
## hit was handled, skipping the normal melee/projectile resolution.
func _resolve_special_hit(_hit: Dictionary) -> bool:
	return false


func _begin_recover() -> void:
	_attack_phase = 2
	_phase_time = 0.0
	var recover: float = _attack.recover
	_kill_tween(_pose_tween)
	_pose_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pose_tween.tween_property(weapon_pivot, "rotation", _deg(rest_rotation), recover)
	_kill_tween(_stance_tween)
	_stance_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_stance_tween.tween_property(model, "rotation:x", 0.0, recover)
	_stance_tween.parallel().tween_property(model, "position:y", 0.0, recover)


func _enter_dodge(to_player: Vector3) -> void:
	_set_state(State.DODGE)
	# Away from the player, angled off to one side or the other.
	_dodge_velocity = (-to_player.normalized()).rotated(Vector3.UP, randf_range(-1.0, 1.0)) * dodge_speed
	_dodge_cooldown_left = dodge_cooldown


func _enter_stagger() -> void:
	_set_state(State.STAGGER)
	_parryable = false
	_kill_tween(_glow_tween)
	_blade_mat.emission_energy_multiplier = 0.0
	_eye_mat.emission_energy_multiplier = _eye_energy * 0.3
	glint.visible = false
	_body_mat.albedo_color = _current_body_color()
	_spawn_label("STAGGERED", STAGGER_TINT, 56)
	velocity = global_basis.z * 2.5 # Reel backwards, cancelling any strike movement.

	# Slump back with the blade drooping.
	_kill_tween(_pose_tween)
	_kill_tween(_stance_tween)
	_pose_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(weapon_pivot, "rotation", _deg(stagger_rotation), 0.3)
	_pose_tween.parallel().tween_property(model, "rotation:x", deg_to_rad(20.0), 0.3)
	_pose_tween.parallel().tween_property(model, "position:y", -0.12, 0.3)


func _recover_from_stagger() -> void:
	_attack_cooldown = 0.6
	_body_mat.albedo_color = _body_color
	_eye_mat.emission_energy_multiplier = _eye_energy
	_kill_tween(_pose_tween)
	_pose_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pose_tween.tween_property(weapon_pivot, "rotation", _deg(rest_rotation), 0.4)
	_pose_tween.parallel().tween_property(model, "rotation:x", 0.0, 0.4)
	_pose_tween.parallel().tween_property(model, "position:y", 0.0, 0.4)
	_notice_player()
	_enter_chase()


func _die() -> void:
	_set_state(State.DEAD)
	_parryable = false
	collision_layer = 0 # Stop blocking the player and taking hits; still rests on the floor.
	health_bar.visible = false
	glint.visible = false
	_kill_tween(_glow_tween)
	_kill_tween(_stance_tween)
	_blade_mat.emission_energy_multiplier = 0.0
	_eye_mat.emission_energy_multiplier = 0.0
	if _glow_light:
		create_tween().tween_property(_glow_light, "light_energy", 0.0, 0.6)
	Audio.play_at("enemy_death", global_position + Vector3.UP)
	Vfx.blood(_body_center(), Vector3.UP, 2.5)
	Vfx.blood_decal(_body_center(), 1.6) # A pool where it falls.
	died.emit()

	_kill_tween(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(model, "rotation", _deg(death_rotation), 0.6) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_pose_tween.parallel().tween_property(model, "position:y", 0.0, 0.3)
	_pose_tween.parallel().tween_property(weapon_pivot, "rotation", _deg(stagger_rotation), 0.4)
	_pose_tween.tween_interval(2.5)
	_pose_tween.tween_property(model, "scale", Vector3.ONE * 0.01, 0.4)
	_pose_tween.tween_callback(queue_free)


# --- Helpers -----------------------------------------------------------------

func _can_see_player() -> bool:
	if not _player or (_player.has_method("is_dead") and _player.is_dead()):
		return false
	var eye := global_position + Vector3.UP * eye_height
	var target := _player.global_position + Vector3.UP * 1.5
	var flat := _flat(target - eye)
	var dist := flat.length()
	if dist > sight_range:
		return false
	if dist > hearing_range and rad_to_deg((-global_basis.z).angle_to(flat)) > sight_angle * 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == _player


## Roughly the middle of the body, for effects.
func _body_center() -> Vector3:
	return global_position + Vector3.UP * eye_height * 0.65


func _player_in_reach(reach: float, arc: float) -> bool:
	if not _player:
		return false
	var to_player := _player.global_position - global_position
	var flat := _flat(to_player)
	return flat.length() <= reach and absf(to_player.y) < 1.5 \
			and rad_to_deg((-global_basis.z).angle_to(flat)) <= arc


func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var radius := sqrt(randf()) * patrol_radius # sqrt spreads points evenly over the disc.
	_patrol_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * radius
	if _nav_ready():
		# Keep the target on walkable ground, e.g. not inside a crate.
		_patrol_target = NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), _patrol_target)
	_patrol_leg_time = 0.0


## Flat direction to walk in to reach target, following the navigation mesh
## around obstacles. Falls back to a straight line if there's no navmesh.
func _path_direction(target: Vector3) -> Vector3:
	if not _nav_ready():
		return _flat(target - global_position).normalized()
	# Only re-path when the target has moved noticeably.
	if nav_agent.target_position.distance_squared_to(target) > 0.25:
		nav_agent.target_position = target
	if nav_agent.is_navigation_finished():
		return _flat(target - global_position).normalized()
	return _flat(nav_agent.get_next_path_position() - global_position).normalized()


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) > 0


func _face_direction(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	var step := speed * delta
	rotation.y += clampf(wrapf(target_yaw - rotation.y, -PI, PI), -step, step)


func _flash_glint() -> void:
	if _state != State.ATTACK:
		return
	glint.visible = true
	glint.scale = Vector3.ONE * 0.01
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(glint, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(glint, "scale", Vector3.ONE * 0.01, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: glint.visible = false)


func _fade_glow(duration: float) -> void:
	_kill_tween(_glow_tween)
	_glow_tween = create_tween()
	_glow_tween.tween_property(_blade_mat, "emission_energy_multiplier", 0.0, duration)
	_glow_tween.parallel().tween_property(_eye_mat, "emission_energy_multiplier", _eye_energy, duration)


func _flash_white() -> void:
	_kill_tween(_flash_tween)
	_body_mat.albedo_color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body_mat, "albedo_color", _current_body_color(), 0.2)


func _current_body_color() -> Color:
	return _body_color.lerp(STAGGER_TINT, 0.6) if _state == State.STAGGER else _body_color


func _update_health_bar() -> void:
	var ratio := clampf(float(health) / max_health, 0.0, 1.0)
	health_bar.visible = ratio > 0.0 and ratio < 1.0
	health_fill.scale.x = maxf(ratio, 0.001)
	health_fill.position.x = -(1.0 - ratio) * HEALTH_FILL_WIDTH * 0.5


func _spawn_label(text: String, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 12
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	# Parented to the level so it doesn't move with the enemy.
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(randf_range(-0.25, 0.25), health_bar.position.y + 0.05, 0.0)
	var tween := label.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y + 0.6, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.tween_callback(label.queue_free)


## Gives this enemy its own copy of every material in its model, so each one
## glows and flashes on its own. Meshes that shared a material still share
## the copy.
func _own_materials() -> void:
	var copies := {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_active_material(0)
		if not material:
			continue
		if not copies.has(material):
			copies[material] = material.duplicate()
		mesh.material_override = copies[material]


## Fires projectile_scene from the glint at the player's chest. A hit with
## "spread" fires that many, fanned out "spread_angle" degrees apart.
func _fire_projectile(hit: Dictionary) -> void:
	if not projectile_scene or not _player:
		return
	var origin := glint.global_position
	Audio.play_at("spell_cast", origin)
	# Aim at the chest, where the player is right now; moving sideways dodges it.
	var aim := (_player.global_position + Vector3.UP * 1.2 - origin).normalized()
	var count: int = hit.get("spread", 1)
	var step := deg_to_rad(float(hit.get("spread_angle", 0.0)))
	for i in count:
		var projectile: Node3D = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = origin
		var direction := aim.rotated(Vector3.UP, (i - (count - 1) * 0.5) * step)
		projectile.call("launch", direction, float(hit.damage), float(hit.knockback), self)


static func _kill_tween(tween: Tween) -> void:
	if tween:
		tween.kill()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _deg(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
