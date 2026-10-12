extends Node3D
## Flickering fire for torches and braziers: wavers the "Light" child's
## energy and the "Flame" child's size with smooth noise, so no two fires
## flicker in sync. set_fire_color() recolors both (e.g. braziers turning
## green for the boss's second phase).

@export var base_energy := 1.6
@export var flicker := 0.25 ## Fraction the light energy wavers by.
@export var flicker_speed := 9.0

## Multiplies brightness and reach; set level-wide by level_lighting.gd.
var strength := 1.0:
	set(value):
		strength = value
		if is_node_ready():
			light.omni_range = _base_range * sqrt(strength)

@onready var light: OmniLight3D = $Light
@onready var flame: MeshInstance3D = $Flame

var _noise := FastNoiseLite.new()
var _time := 0.0
var _flame_material: StandardMaterial3D
var _flame_scale: Vector3
var _base_range: float


func _ready() -> void:
	_base_range = light.omni_range
	light.omni_range = _base_range * sqrt(strength)
	_noise.seed = randi()
	_time = randf() * 100.0
	_flame_scale = flame.scale
	# Own copy so recoloring one fire doesn't recolor them all.
	_flame_material = flame.get_active_material(0).duplicate()
	flame.material_override = _flame_material


func _process(delta: float) -> void:
	_time += delta
	var n := _noise.get_noise_1d(_time * flicker_speed * 10.0) # -1..1
	light.light_energy = base_energy * strength * (1.0 + n * flicker)
	flame.scale = _flame_scale * Vector3(1.0 - n * 0.08, 1.0 + n * 0.2, 1.0 - n * 0.08)


func set_fire_color(color: Color, duration := 1.0) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "light_color", color, duration)
	tween.parallel().tween_property(_flame_material, "albedo_color", color, duration)
	tween.parallel().tween_property(_flame_material, "emission", color, duration)
