extends Node3D
## A bonfire checkpoint. Walk up and press interact (E) to rest: it becomes
## the place you come back to after dying, and resting reloads the level
## Souls-style, so you return healed with full flasks and enemies respawned.
##
## Expects children: Area (Area3D, where you can rest) and SpawnPoint
## (Marker3D, where the player appears; its -Z is the facing direction).

@export var checkpoint_id := "checkpoint"
@export var prompt := "[E] Rest at the bonfire"

@onready var area: Area3D = $Area
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	if Progress.checkpoint_id == checkpoint_id:
		# Wait a frame so the player exists, then bring them here.
		_place_player.call_deferred()


func interact(player: Node) -> void:
	Progress.checkpoint_id = checkpoint_id
	Audio.play_at("relic_pickup", global_position)
	if player.has_method("rest_and_reload"):
		player.call("rest_and_reload")


func _place_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_transform = spawn_point.global_transform


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_interactable"):
		body.call("set_interactable", self, prompt)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("clear_interactable"):
		body.call("clear_interactable", self)
