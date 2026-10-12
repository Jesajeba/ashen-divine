extends Node3D
## Title screen: a campfire in a foggy night forest behind a menu on the left.
## The forest is planted procedurally from a fixed seed, so it looks the same
## every time. The camera drifts slowly around its starting point.

const GAME_SCENE := "res://level/level_01.tscn"

@export var tree_count := 90
@export var tree_seed := 7
@export var clearing_radius := 5.0 ## No trees closer than this to the fire.
@export var forest_radius := 32.0
@export var rock_count := 14
@export var camera_drift := Vector3(0.5, 0.15, 0.2) ## Meters the camera wanders on each axis.

@onready var camera: Camera3D = $Camera3D
@onready var focus: Marker3D = $CameraFocus
@onready var trees: Node3D = $Trees
@onready var fade: ColorRect = $UI/Fade
@onready var begin_button: Button = %BeginButton
@onready var quit_button: Button = %QuitButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue

var _camera_base: Vector3
var _time := 0.0
var _leaving := false


func _ready() -> void:
	# Coming back from the game, make sure nothing is still paused or slowed.
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_camera_base = camera.position
	_plant_forest()

	volume_slider.value = roundf(Audio.master_volume * 100.0)
	volume_value.text = "%d%%" % roundi(volume_slider.value)
	volume_slider.value_changed.connect(_on_volume_changed)
	begin_button.pressed.connect(_on_begin_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	begin_button.grab_focus()

	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 2.0)


func _process(delta: float) -> void:
	_time += delta
	camera.position = _camera_base + Vector3(
			sin(_time * 0.13) * camera_drift.x,
			sin(_time * 0.21) * camera_drift.y,
			sin(_time * 0.09) * camera_drift.z)
	camera.look_at(focus.global_position)


func _on_begin_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	begin_button.disabled = true
	quit_button.disabled = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))


func _on_volume_changed(value: float) -> void:
	Audio.set_master_volume(value / 100.0)
	volume_value.text = "%d%%" % roundi(value)


## Scatters pines and rocks around the clearing, keeping the view from the
## camera to the fire clear.
func _plant_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed

	var bark := _material(Color(0.12, 0.09, 0.07))
	var needles := _material(Color(0.06, 0.1, 0.07))
	var stone := _material(Color(0.2, 0.2, 0.21))
	var trunk_mesh := _cylinder(0.12, 0.2, 2.4, bark)
	var cone_meshes: Array[Mesh] = [
		_cylinder(0.0, 1.5, 2.4, needles),
		_cylinder(0.0, 1.15, 2.0, needles),
		_cylinder(0.0, 0.8, 1.7, needles),
	]
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.5
	rock_mesh.height = 0.6
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4
	rock_mesh.material = stone

	var planted := 0
	var attempts := 0
	while planted < tree_count and attempts < tree_count * 10:
		attempts += 1
		var spot := _random_spot(rng, clearing_radius, forest_radius)
		if _blocks_view(spot):
			continue
		var tree := Node3D.new()
		trees.add_child(tree)
		tree.position = spot
		tree.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05))
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.7)
		_add_mesh(tree, trunk_mesh, Vector3(0, 1.2, 0))
		for i in cone_meshes.size():
			_add_mesh(tree, cone_meshes[i], Vector3(0, 2.3 + i * 1.15, 0))
		planted += 1

	for i in rock_count:
		var spot := _random_spot(rng, 1.5, clearing_radius + 3.0)
		if _blocks_view(spot):
			continue
		var rock := MeshInstance3D.new()
		rock.mesh = rock_mesh
		trees.add_child(rock)
		rock.position = spot + Vector3.DOWN * 0.1
		rock.rotation.y = rng.randf() * TAU
		rock.scale = Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.4, 0.9), rng.randf_range(0.5, 1.4))


func _random_spot(rng: RandomNumberGenerator, min_radius: float, max_radius: float) -> Vector3:
	var angle := rng.randf() * TAU
	# sqrt spreads points evenly over the ring's area.
	var radius := sqrt(rng.randf_range(min_radius * min_radius, max_radius * max_radius))
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## True if something at spot would stand between the camera and the fire.
func _blocks_view(spot: Vector3) -> bool:
	var to_fire := Vector2(-_camera_base.x, -_camera_base.z)
	var to_spot := Vector2(spot.x - _camera_base.x, spot.z - _camera_base.z)
	var along := to_spot.dot(to_fire.normalized())
	if along < -2.0 or along > to_fire.length() + 1.0:
		return false
	var off_line := absf(to_spot.cross(to_fire.normalized()))
	return off_line < 3.0 + along * 0.25 # The corridor widens toward the fire.


func _add_mesh(parent: Node3D, mesh: Mesh, offset: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	instance.position = offset


func _cylinder(top: float, bottom: float, height: float, material: Material) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = material
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
