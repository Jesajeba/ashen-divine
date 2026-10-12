extends Area3D
## Pickup that permanently raises the player's max health. Collected by
## walking into it. The "Gem" child floats and spins.

@export var max_health_bonus := 25.0

@onready var gem: Node3D = $Gem

var _time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	gem.position.y = 1.0 + sin(_time * 2.0) * 0.1
	gem.rotate_y(delta * 1.5)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not body.has_method("grant_max_health"):
		return
	body.grant_max_health(max_health_bonus)
	Audio.play("relic_pickup")
	if body.has_method("show_message"):
		body.show_message("Vitality rises: max HP +%d" % max_health_bonus)
	queue_free()
