@tool
class_name LevelBlock
extends StaticBody3D
## Box-shaped piece of level geometry. Builds a mesh and a matching collision
## shape from size, so walls and floors can be laid out by just setting size,
## material and transform. Works in the editor too.

@export var size := Vector3(2, 2, 2):
	set(value):
		size = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return # Built in _ready once the exported values are all set.
	if not _mesh_instance:
		# Generated children have no owner, so they're never saved into the scene.
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
		_collision = CollisionShape3D.new()
		add_child(_collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_mesh_instance.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape


func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance
