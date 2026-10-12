class_name Reaper
extends Enemy
## Boss: a towering reaper with a scythe. Dormant until awaken() is called
## (by its arena), then hunts the player relentlessly.
##
## Phase one moves, each with its own stance:
## - Cleave: upright, scythe cocked far out to its right; one huge sweep.
## - Combo: hunched forward, scythe held low to its right; sweep, backsweep,
##   then an overhead chop.
## - Dashing cleave: from mid range, crouches low leaning forward with the
##   scythe trailing behind; charges in with a sweep.
## - Scythe throw: leans back with the scythe cocked over its shoulder, then
##   hurls it. The scythe spins out to where the player was and flies back to
##   its hand, hitting on the way out and the way back. The reaper is unarmed
##   until it returns.
##
## At half health it enters phase two: wings unfurl, its glow turns green, it
## attacks more often, moves faster, and adds two moves:
## - Flame barrage: leaps backwards to make space with the scythe raised high,
##   then sweeps it down three times, loosing a fan of three green flames each.
## - Sky barrage: spreads its wings, rises into the air with the scythe raised,
##   then rains five orbs down at the player. Each orb's landing spot is marked
##   on the ground by a ring and it explodes there, hurting anyone inside.
##   Shooting it as it fires knocks it out of the air (parry).
##
## Health is exposed as value/max_value with a changed signal so a HUD bar
## (resource_bar.gd) can track it.

signal changed(value: float, max_value: float)
signal phase_two_started

@export var boomerang_scene: PackedScene
@export var aoe_orb_scene: PackedScene
@export var aoe_spread := 1.5 ## Max meters an AoE orb lands from the player, so standing still isn't safe either.
@export var hover_rise_speed := 5.0 ## How quickly it closes the gap to its flying height.
@export var voice_chance := 0.3 ## Chance it growls when starting an attack.
@export var phase_two_color := Color(0.3, 1.0, 0.35)
@export var phase_two_cooldown_scale := 0.45 ## Multiplies the attack cooldowns in phase two.
@export var phase_two_speed_scale := 1.25 ## Multiplies chase speed in phase two.

var value: float:
	get:
		return maxf(health, 0)
var max_value: float:
	get:
		return max_health

## See Enemy.ATTACKS for the format. Poses are the scythe pivot's rotation in
## degrees: the pole points along +Y and the blade forward (-Z) at the top.
const REAPER_ATTACKS := [
	{
		"name": "cleave", "min_range": 0.0, "max_range": 3.6, "cooldown": 0.0,
		"lean": 4.0, "crouch": 0.0, "recover": 0.9,
		"hits": [
			{ "windup": 1.0, "windup_rot": Vector3(0, -50, -80), "strike_rot": Vector3(0, 170, -80),
				"strike": 0.22, "creep": 0.8, "step": 9.0, "reach": 3.4, "arc": 100.0,
				"damage": 30, "knockback": 7.0 },
		],
	},
	{
		"name": "combo", "min_range": 0.0, "max_range": 3.4, "cooldown": 5.0,
		"lean": -14.0, "crouch": -0.1, "recover": 1.1,
		"hits": [
			{ "windup": 0.95, "windup_rot": Vector3(-20, -40, -80), "strike_rot": Vector3(0, 160, -80),
				"strike": 0.2, "creep": 1.0, "step": 8.0, "reach": 3.2, "arc": 90.0,
				"damage": 18, "knockback": 3.0 },
			{ "windup": 0.35, "windup_rot": Vector3(0, 200, -80), "strike_rot": Vector3(0, 0, -80),
				"strike": 0.2, "creep": 1.5, "step": 8.0, "reach": 3.2, "arc": 90.0,
				"damage": 18, "knockback": 3.0 },
			{ "windup": 0.55, "windup_rot": Vector3(40, 0, 0), "strike_rot": Vector3(-100, 0, 0),
				"strike": 0.2, "creep": 1.5, "step": 9.0, "reach": 3.4, "arc": 40.0,
				"damage": 28, "knockback": 8.0 },
		],
	},
	{
		"name": "dash_cleave", "min_range": 5.0, "max_range": 12.0, "cooldown": 5.0,
		"lean": -20.0, "crouch": -0.3, "recover": 1.2,
		"hits": [
			{ "windup": 0.9, "windup_rot": Vector3(-10, -70, -70), "strike_rot": Vector3(0, 170, -80),
				"strike": 0.5, "creep": 0.0, "step": 18.0, "reach": 2.8, "arc": 100.0,
				"damage": 32, "knockback": 9.0, "dash": true },
		],
	},
	{
		"name": "scythe_throw", "min_range": 4.0, "max_range": 16.0, "cooldown": 7.0,
		"lean": 12.0, "crouch": 0.0, "recover": 2.2,
		"hits": [
			{ "windup": 1.0, "windup_rot": Vector3(30, -30, -60), "strike_rot": Vector3(0, 140, -80),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 22, "knockback": 6.0, "boomerang": true },
		],
	},
]
## "fly_height" (attack level) lifts it this many meters for the whole attack.
## "aoe" hits fire aoe_orb_scene at the ground near the player.
const PHASE_TWO_ATTACKS := [
	{
		"name": "flame_barrage", "min_range": 0.0, "max_range": 14.0, "cooldown": 6.0,
		"lean": -6.0, "crouch": 0.0, "recover": 0.8,
		"hits": [
			{ "windup": 1.0, "windup_rot": Vector3(60, 0, 0), "strike_rot": Vector3(-40, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"backstep_speed": 11.0, "backstep_time": 0.4, "hop": 4.0,
				"damage": 15, "knockback": 3.0, "projectile": true, "spread": 3, "spread_angle": 15.0 },
			{ "windup": 0.45, "windup_rot": Vector3(45, 0, 0), "strike_rot": Vector3(-40, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 15, "knockback": 3.0, "projectile": true, "spread": 3, "spread_angle": 15.0 },
			{ "windup": 0.45, "windup_rot": Vector3(45, 0, 0), "strike_rot": Vector3(-40, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 15, "knockback": 3.0, "projectile": true, "spread": 3, "spread_angle": 15.0 },
		],
	},
	{
		"name": "sky_barrage", "min_range": 0.0, "max_range": 16.0, "cooldown": 10.0,
		"lean": 10.0, "crouch": 0.0, "recover": 1.0, "fly_height": 4.5,
		"hits": [
			{ "windup": 1.3, "windup_rot": Vector3(70, 0, 0), "strike_rot": Vector3(-30, 0, 0),
				"strike": 0.15, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 20, "knockback": 6.0, "aoe": true },
			{ "windup": 0.3, "windup_rot": Vector3(40, 0, 0), "strike_rot": Vector3(-30, 0, 0),
				"strike": 0.15, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 20, "knockback": 6.0, "aoe": true },
			{ "windup": 0.3, "windup_rot": Vector3(40, 0, 0), "strike_rot": Vector3(-30, 0, 0),
				"strike": 0.15, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 20, "knockback": 6.0, "aoe": true },
			{ "windup": 0.3, "windup_rot": Vector3(40, 0, 0), "strike_rot": Vector3(-30, 0, 0),
				"strike": 0.15, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 20, "knockback": 6.0, "aoe": true },
			{ "windup": 0.3, "windup_rot": Vector3(40, 0, 0), "strike_rot": Vector3(-30, 0, 0),
				"strike": 0.15, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 20, "knockback": 6.0, "aoe": true },
		],
	},
]
const WING_FOLDED := Vector3(0, 0, 0) ## Degrees; z is mirrored for the right wing.
const WING_SPREAD := Vector3(0, 25, -20)
const WING_FLIGHT := Vector3(0, 10, -45)

@onready var phase_light: OmniLight3D = $Model/PhaseLight
@onready var wings: Node3D = $Model/Wings
@onready var wing_left: Node3D = $Model/Wings/Left
@onready var wing_right: Node3D = $Model/Wings/Right

var _awake := false
var _phase_two := false
var _scythe_out := false
var _hovering := false
var _hover_y := 0.0
var _wing_pose := WING_FOLDED
var _wing_target := WING_FOLDED


func _ready() -> void:
	super()
	wings.visible = false
	wings.scale = Vector3.ONE * 0.01
	phase_light.visible = false


## Wakes the boss up to fight. Until then it stands still.
func awaken() -> void:
	if _awake:
		return
	_awake = true
	_notice_player()
	_growl()


func is_phase_two() -> bool:
	return _phase_two


func take_hit(damage: int, impulse: Vector3) -> int:
	_awake = true # Hitting it wakes it up, arena or not.
	var dealt := super(damage, impulse)
	if not _phase_two and health > 0 and health <= max_health / 2:
		_enter_phase_two()
	return dealt


func _get_attacks() -> Array:
	if _phase_two:
		return REAPER_ATTACKS + PHASE_TWO_ATTACKS
	return REAPER_ATTACKS


func _choose_attack(dist: float) -> Dictionary:
	if _scythe_out:
		return {} # Can't attack without the scythe.
	return super(dist)


func _tick_patrol(delta: float) -> Vector3:
	if not _awake:
		return Vector3.ZERO
	return super(delta)


func _update_health_bar() -> void:
	health_bar.visible = false # The boss bar on the HUD shows health instead.
	changed.emit(value, max_value)


func _process(delta: float) -> void:
	super(delta)
	if not wings.visible:
		return
	# Ease toward the target wing pose, with a flap on top: lazy on the ground,
	# fast in the air.
	_wing_pose = _wing_pose.lerp(_wing_target, 1.0 - exp(-6.0 * delta))
	var t := Time.get_ticks_msec() / 1000.0
	var flap := sin(t * 9.0) * 18.0 if _hovering else sin(t * 2.5) * 5.0
	wing_left.rotation_degrees = _wing_pose + Vector3(0, 0, flap)
	wing_right.rotation_degrees = Vector3(_wing_pose.x, -_wing_pose.y, -_wing_pose.z - flap)


func _enter_attack(attack: Dictionary) -> void:
	super(attack)
	if randf() < voice_chance:
		_growl()
	if attack.has("fly_height"):
		_hovering = true
		_hover_y = global_position.y + float(attack.fly_height)
		_wing_target = WING_FLIGHT


func _enter_stagger() -> void:
	super()
	_growl()


func _growl() -> void:
	Audio.play_at("reaper_voice", global_position + Vector3.UP * eye_height)


func _set_state(state: State) -> void:
	super(state)
	if state != State.ATTACK and _hovering:
		_hovering = false # Drops back down, including when parried mid-air.
		_wing_target = WING_SPREAD


func _apply_custom_vertical(_delta: float) -> bool:
	if not _hovering:
		return false
	velocity.y = (_hover_y - global_position.y) * hover_rise_speed
	return true


func _resolve_special_hit(hit: Dictionary) -> bool:
	if hit.get("aoe", false):
		_fire_aoe_orb(hit)
		return true
	if not hit.get("boomerang", false):
		return false
	if not boomerang_scene or not _player:
		return true
	var scythe: Node3D = boomerang_scene.instantiate()
	get_parent().add_child(scythe)
	scythe.global_position = glint.global_position
	scythe.call("launch", self, _player.global_position + Vector3.UP * 1.2, float(hit.damage), float(hit.knockback))
	_scythe_out = true
	weapon_pivot.visible = false
	return true


func _fire_aoe_orb(hit: Dictionary) -> void:
	if not aoe_orb_scene or not _player:
		return
	var orb: Node3D = aoe_orb_scene.instantiate()
	get_parent().add_child(orb)
	orb.global_position = glint.global_position
	Audio.play_at("spell_cast", glint.global_position)
	# Land near the player on the arena floor (the height it started at).
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * sqrt(randf()) * aoe_spread
	var target := Vector3(_player.global_position.x, _home.y, _player.global_position.z) + offset
	orb.call("launch", target, float(hit.damage), float(hit.knockback))


## Called by the thrown scythe when it's back in hand (or lost).
func catch_scythe() -> void:
	_scythe_out = false
	weapon_pivot.visible = true


## Where the thrown scythe flies back to.
func get_hand_position() -> Vector3:
	return weapon_pivot.global_position


func _enter_phase_two() -> void:
	_phase_two = true
	attack_cooldown_min *= phase_two_cooldown_scale
	attack_cooldown_max *= phase_two_cooldown_scale
	chase_speed *= phase_two_speed_scale
	_attack_cooldown = maxf(_attack_cooldown, 1.0) # A beat to let the change register.

	_blade_mat.emission = phase_two_color
	_eye_mat.emission = phase_two_color
	_eye_mat.albedo_color = phase_two_color
	_eye_energy *= 2.0
	_eye_mat.emission_energy_multiplier = _eye_energy
	phase_light.light_color = phase_two_color
	phase_light.visible = true
	if _glow_light:
		_glow_light.light_color = phase_two_color
	_spawn_label("...", phase_two_color, 96)
	Audio.play("boss_phase_two") # Not positional: it should fill the arena.

	# Unfurl the wings.
	wings.visible = true
	_wing_pose = WING_FOLDED
	_wing_target = WING_SPREAD
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wings, "scale", Vector3.ONE, 0.8)
	phase_two_started.emit()
