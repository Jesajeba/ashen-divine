class_name Caster
extends Enemy
## Hooded caster. Keeps its distance, circling at range, and hurls glowing
## bolts that fly straight at where the player was when released, so moving
## sideways (or dodging) avoids them. Backs away when crowded, and shoves with
## its staff if cornered. Fragile up close.
##
## Tells:
## - Bolt: raises the staff high behind its head, then snaps it forward.
## - Volley: crouches and holds the staff out to its left; three bolts in a row.
## - Shove: only when you're close. Leans back with the staff cocked to its
##   right, then sweeps it across.
##
## Like every enemy, shooting it as an attack is released parries it.

@export_group("Spacing")
@export var keep_min := 6.0 ## Backs away when the player is closer than this...
@export var keep_max := 11.0 ## ...and closes in when farther.
@export var retreat_speed := 2.6

## Poses are the staff pivot's rotation in degrees; the staff points along +Y.
## See Enemy.ATTACKS for the format.
const CASTER_ATTACKS := [
	{
		"name": "bolt", "min_range": 3.0, "max_range": 15.0, "cooldown": 0.0,
		"lean": 6.0, "crouch": 0.0, "recover": 0.8,
		"hits": [
			{ "windup": 1.0, "windup_rot": Vector3(40, 0, 0), "strike_rot": Vector3(-80, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 18, "knockback": 3.0, "projectile": true },
		],
	},
	{
		"name": "volley", "min_range": 4.0, "max_range": 15.0, "cooldown": 7.0,
		"lean": -8.0, "crouch": -0.12, "recover": 1.2,
		"hits": [
			{ "windup": 1.2, "windup_rot": Vector3(0, 0, 70), "strike_rot": Vector3(-80, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 10, "knockback": 2.0, "projectile": true },
			{ "windup": 0.35, "windup_rot": Vector3(-50, 0, 0), "strike_rot": Vector3(-80, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 10, "knockback": 2.0, "projectile": true },
			{ "windup": 0.35, "windup_rot": Vector3(-50, 0, 0), "strike_rot": Vector3(-80, 0, 0),
				"strike": 0.2, "creep": 0.0, "step": 0.0, "reach": 0.0, "arc": 0.0,
				"damage": 10, "knockback": 2.0, "projectile": true },
		],
	},
	{
		"name": "shove", "min_range": 0.0, "max_range": 2.2, "cooldown": 2.5,
		"lean": 12.0, "crouch": 0.0, "recover": 0.8,
		"hits": [
			{ "windup": 0.55, "windup_rot": Vector3(0, -40, -80), "strike_rot": Vector3(0, 140, -80),
				"strike": 0.18, "creep": 0.0, "step": 5.0, "reach": 2.2, "arc": 80.0,
				"damage": 10, "knockback": 9.0 },
		],
	},
]


func _get_attacks() -> Array:
	return CASTER_ATTACKS


func _engage_velocity(to_target: Vector3, dist: float, sees: bool, move_dir: Vector3) -> Vector3:
	if not sees:
		# Lost sight: go to where the player was last seen.
		return Vector3.ZERO if dist < 0.5 else move_dir * chase_speed
	var toward := to_target.normalized()
	var side := toward.cross(Vector3.UP) * _strafe_dir
	if dist < keep_min:
		return (-toward + side * 0.5).normalized() * retreat_speed
	if dist > keep_max:
		return move_dir * chase_speed
	return side * strafe_speed # Circle at range.
