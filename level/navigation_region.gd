extends NavigationRegion3D
## Bakes the navigation mesh when the level loads, unless it was already baked
## in the editor (select the node and press "Bake NavigationMesh").
##
## Geometry comes from nodes in the navigation mesh's source group (see the
## NavigationMesh resource's Geometry settings), so level pieces can live
## anywhere in the scene. Add new obstacles and floors to that group.


func _ready() -> void:
	if navigation_mesh and navigation_mesh.get_polygon_count() == 0:
		bake_navigation_mesh(false)
