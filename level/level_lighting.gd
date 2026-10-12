extends Node3D
## Level-wide lighting controls. Put this on the node holding the level's
## lights: light_strength scales every light under it (torches, braziers and
## plain lights; their reach grows too), and ambient_energy sets the
## environment's base fill light so the darkest corners aren't pitch black.
## Applied when the level loads.

@export var light_strength := 1.7
@export var ambient_energy := 0.5
@export var world_environment: WorldEnvironment


func _ready() -> void:
	for light in find_children("*", "", true, false):
		if "strength" in light:
			light.strength = light_strength # Torches and braziers (flame_light.gd).
		elif light is OmniLight3D and not light.get_parent().has_method("set_fire_color"):
			light.light_energy *= light_strength
			light.omni_range *= sqrt(light_strength)
	if world_environment and world_environment.environment:
		world_environment.environment.ambient_light_energy = ambient_energy
