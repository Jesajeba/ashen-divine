extends Area3D
## Pickup that permanently raises the player's max health. Collected by
## walking into it. The "Gem" child floats and spins.

@export var max_health_bonus := 25.0

@onready var gem: Node3D = $Gem

var _time := 0.0


func _ready() -> void:
	if Progress.relic_taken:
		# Already found this playthrough: just give the bonus back quietly.
		_restore_bonus.call_deferred() # Once the player is ready.
		return
	body_entered.connect(_on_body_entered)


func _restore_bonus() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("grant_max_health"):
		player.call("grant_max_health", max_health_bonus, false)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	gem.position.y = 1.0 + sin(_time * 2.0) * 0.1
	gem.rotate_y(delta * 1.5)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not body.has_method("grant_max_health"):
		return
	body.grant_max_health(max_health_bonus)
	Progress.relic_taken = true
	Audio.play("relic_pickup")
	if body.has_method("show_message"):
		body.show_message("Vitality rises: max HP +%d" % max_health_bonus)
	queue_free()
