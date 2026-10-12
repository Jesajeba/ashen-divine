class_name Dog
extends Enemy
## Fast, low, fragile hound. Closes distance quickly, circles tightly, bites
## often and dodges a lot. Its attacks are quick but each still has a tell:
## - Bite: rears its head up and back, then snaps.
## - Double bite: drops its head low and turned to one side; two snaps.
## - Leap: from mid range, crouches low and coils, then pounces.

## Poses are the neck pivot's rotation in degrees; the head points along -Z
## (positive X tips the nose up). See Enemy.ATTACKS for the format.
const DOG_ATTACKS := [
	{
		"name": "bite", "min_range": 0.0, "max_range": 1.9, "cooldown": 0.0,
		"lean": 8.0, "crouch": 0.0, "recover": 0.5,
		"hits": [
			{ "windup": 0.45, "windup_rot": Vector3(30, 0, 0), "strike_rot": Vector3(-25, 0, 0),
				"strike": 0.15, "creep": 1.0, "step": 9.0, "reach": 1.7, "arc": 60.0,
				"damage": 12, "knockback": 3.0 },
		],
	},
	{
		"name": "double_bite", "min_range": 0.0, "max_range": 2.0, "cooldown": 3.5,
		"lean": -10.0, "crouch": -0.08, "recover": 0.7,
		"hits": [
			{ "windup": 0.6, "windup_rot": Vector3(-20, 35, 0), "strike_rot": Vector3(-15, -35, 0),
				"strike": 0.15, "creep": 1.5, "step": 9.0, "reach": 1.8, "arc": 70.0,
				"damage": 10, "knockback": 2.0 },
			{ "windup": 0.25, "windup_rot": Vector3(20, -20, 0), "strike_rot": Vector3(-25, 10, 0),
				"strike": 0.15, "creep": 2.0, "step": 9.0, "reach": 1.8, "arc": 70.0,
				"damage": 10, "knockback": 3.0 },
		],
	},
	{
		"name": "leap", "min_range": 3.0, "max_range": 7.0, "cooldown": 4.0,
		"lean": -8.0, "crouch": -0.18, "recover": 0.9,
		"hits": [
			{ "windup": 0.6, "windup_rot": Vector3(10, 0, 0), "strike_rot": Vector3(-30, 0, 0),
				"strike": 0.4, "creep": 0.0, "step": 14.0, "reach": 1.5, "arc": 70.0,
				"damage": 18, "knockback": 6.0, "dash": true },
		],
	},
]


func _get_attacks() -> Array:
	return DOG_ATTACKS
