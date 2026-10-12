extends Node
## Global visual effects (autoloaded as "Vfx"). Spawns short-lived particle
## bursts and blood decals into the current scene. Everything is built in code
## from the settings below, so there are no extra scene files to manage.

const MAX_DECALS := 40 ## Oldest blood decals are removed beyond this.

@export var blood_color := Color(0.42, 0.02, 0.02)
@export var spark_color := Color(1.0, 0.65, 0.3)
@export var parry_color := Color(1.0, 0.92, 0.7)

var _blood_process: ParticleProcessMaterial
var _blood_mesh: Mesh
var _spark_process: ParticleProcessMaterial
var _spark_mesh: Mesh
var _parry_mesh: Mesh
var _decal_texture: Texture2D
var _decals: Array[Decal] = []


func _ready() -> void:
	_blood_process = _make_process(35.0, 1.5, 4.5, Vector3(0, -9.8, 0), 0.6, 1.4)
	_blood_mesh = _make_sphere(0.025, _make_material(blood_color, false))
	_spark_process = _make_process(60.0, 2.0, 6.0, Vector3(0, -4.0, 0), 0.5, 1.0)
	_spark_mesh = _make_sphere(0.012, _make_material(spark_color, true))
	_parry_mesh = _make_sphere(0.018, _make_material(parry_color, true))
	_decal_texture = _make_splat_texture()


## Blood spray flying along direction, sometimes leaving a pool below.
## amount scales the number of droplets and the chance/size of the pool.
func blood(position: Vector3, direction: Vector3, amount := 1.0) -> void:
	_burst(_blood_process, _blood_mesh, position, direction, roundi(18 * amount), 0.9)
	if randf() < 0.5 * amount:
		blood_decal(position, randf_range(0.5, 0.9) * sqrt(amount))


## Sparks bouncing off a surface, e.g. a bullet hitting a wall.
func sparks(position: Vector3, normal: Vector3) -> void:
	_burst(_spark_process, _spark_mesh, position, normal, 14, 0.35)


## A bright burst and flash of light for a successful parry.
func parry_flash(position: Vector3) -> void:
	_burst(_spark_process, _parry_mesh, position, Vector3.UP, 40, 0.45)
	var light := OmniLight3D.new()
	light.light_color = parry_color
	light.light_energy = 6.0
	light.omni_range = 6.0
	var scene := _scene()
	if not scene:
		return
	scene.add_child(light)
	light.global_position = position
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)


## A blood splat on whatever floor is below position (within 4 m).
func blood_decal(position: Vector3, size := 0.7) -> void:
	var scene := _scene()
	if not scene:
		return
	var query := PhysicsRayQueryParameters3D.create(position, position + Vector3.DOWN * 4.0)
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D:
		return
	var decal := Decal.new()
	decal.texture_albedo = _decal_texture
	decal.size = Vector3(size, 0.6, size * randf_range(0.7, 1.3))
	scene.add_child(decal)
	decal.global_position = hit.position
	decal.rotate_y(randf() * TAU)
	_decals.append(decal)
	while _decals.size() > MAX_DECALS:
		var oldest: Decal = _decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _burst(process: ParticleProcessMaterial, mesh: Mesh, position: Vector3,
		direction: Vector3, amount: int, lifetime: float) -> void:
	var scene := _scene()
	if not scene or amount <= 0:
		return
	var particles := GPUParticles3D.new()
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(particles)
	particles.global_position = position
	# The process material sprays along -Z, so point -Z along direction.
	if direction.length_squared() > 0.0001:
		var up := Vector3.FORWARD if absf(direction.normalized().y) > 0.99 else Vector3.UP
		particles.look_at(position + direction, up)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(particles.queue_free)


func _scene() -> Node3D:
	return get_tree().current_scene as Node3D


func _make_process(spread: float, speed_min: float, speed_max: float, gravity: Vector3,
		scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0, -1)
	process.spread = spread
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = gravity
	process.scale_min = scale_min
	process.scale_max = scale_max
	return process


func _make_material(color: Color, glowing: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3
	if glowing:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
	return material


func _make_sphere(radius: float, material: Material) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = material
	return mesh


## A soft round blood splat: dark opaque center fading out at the edge.
func _make_splat_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color(blood_color, 0.95), Color(blood_color.darkened(0.2), 0.85),
		Color(blood_color.darkened(0.4), 0.3), Color(0, 0, 0, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
