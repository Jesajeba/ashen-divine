@tool
extends LevelBlock
## A wall that isn't really there. Striking or shooting it (take_hit) makes it
## fade away, opening whatever it hides. Give it a transparency-enabled
## material so the fade shows.

@export var message := "Illusory wall"

var _revealed := false


func _ready() -> void:
	super()
	if not Engine.is_editor_hint() and Progress.illusory_wall_revealed:
		queue_free() # Already found this playthrough.


func take_hit(_damage: int, _impulse: Vector3) -> int:
	if _revealed:
		return 0
	_revealed = true
	Progress.illusory_wall_revealed = true
	Audio.play_at("illusory_wall", global_position)
	collision_layer = 0
	collision_mask = 0

	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_message"):
		player.show_message(message)

	var mesh := get_mesh_instance()
	var faded: StandardMaterial3D = mesh.get_active_material(0).duplicate()
	mesh.material_override = faded
	var tween := create_tween()
	tween.tween_property(faded, "albedo_color:a", 0.0, 1.2)
	tween.tween_callback(queue_free)
	return 0
