extends Node3D
## Runs a boss fight. When the player walks into the Trigger area, the fog
## gate seals behind them, the boss bar appears and the boss wakes up. When the
## boss dies, the fog gate fades away, the bar is hidden, a victory banner
## shows, and then the ending plays.

@export var boss: Enemy
@export var defeat_message := "GOD SLAIN"
@export var defeat_color := Color(0.95, 0.8, 0.45)
## Shown on a black screen after victory before returning to the main menu.
## Leave empty to let the player keep exploring instead.
@export var ending_text := "Thanks for playing"
@export var ending_delay := 8.5 ## Seconds after the boss dies (the banner is done by then).
@export var boss_music := "boss" ## Track from Audio.MUSIC played during the fight.
@export var after_music := "main" ## Track to return to after victory.
## Fires in this group (flame_light.gd) turn this color when the boss enters
## its second phase.
@export var phase_two_fire_group := &"arena_brazier"
@export var phase_two_fire_color := Color(0.3, 1.0, 0.35)

@onready var trigger: Area3D = $Trigger
@onready var fog_gate: StaticBody3D = $FogGate
@onready var boss_hud: CanvasLayer = $BossHUD

var _started := false


func _ready() -> void:
	boss_hud.visible = false
	fog_gate.collision_layer = 0 # Passable until the fight starts.
	trigger.body_entered.connect(_on_trigger_body_entered)
	if boss:
		boss.died.connect(_on_boss_died)
		if boss.has_signal("phase_two_started"):
			boss.connect("phase_two_started", _on_boss_phase_two)


func _on_trigger_body_entered(body: Node3D) -> void:
	if _started or not body.is_in_group("player") or not is_instance_valid(boss):
		return
	_started = true
	fog_gate.collision_layer = 1 # No leaving until it's over.
	boss_hud.visible = true
	boss.call("awaken")
	Audio.play_music(boss_music, 1.0)


func _on_boss_phase_two() -> void:
	for fire in get_tree().get_nodes_in_group(phase_two_fire_group):
		if fire.has_method("set_fire_color"):
			fire.set_fire_color(phase_two_fire_color, 1.5)


func _on_boss_died() -> void:
	Audio.play("boss_death")
	Audio.play_music(after_music, 4.0)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_banner"):
		# Wait a beat so the death itself lands first.
		get_tree().create_timer(1.0).timeout.connect(
				Callable(player, "show_banner").bind(defeat_message, defeat_color, 3.5))
	if ending_text != "" and player and player.has_method("play_ending"):
		# After the banner has faded, close out the game.
		get_tree().create_timer(ending_delay).timeout.connect(
				Callable(player, "play_ending").bind(ending_text))

	# Fade the fog gate away and open the way back.
	fog_gate.collision_layer = 0
	var mesh: MeshInstance3D = fog_gate.get_node("Mesh")
	var material: StandardMaterial3D = mesh.get_active_material(0).duplicate()
	mesh.material_override = material
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 1.5)
	tween.tween_callback(fog_gate.queue_free)
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void: boss_hud.visible = false)
