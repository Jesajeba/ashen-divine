extends CharacterBody3D
## First-person controller: WASD to walk, mouse to look, Space to jump,
## Shift to dodge in the direction you're moving (forward if standing still),
## left click to attack (three-hit rapier combo; hold to charge a lunging heavy
## thrust), right click to fire the pistol, F to drink from the healing flask.
## Dodging, attacking and shooting cost stamina (see the Stamina node).
## Dodges have invincibility frames. Shooting an enemy mid-attack parries it.
## Esc opens the pause menu (PauseMenu node). If the mouse gets freed some
## other way, clicking inside the window captures it again.

@export var walk_speed := 4.0
@export var acceleration := 9.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002 ## Radians per pixel of mouse movement.
@export_range(1.0, 89.0) var max_pitch_degrees := 89.0
@export var attack_move_multiplier := 0.35 ## Walk speed multiplier while attacking, charging or drinking.
@export var step_length := 1.9 ## Meters walked between footstep sounds.
@export var land_sound_speed := 4.0 ## Falling faster than this (m/s) plays a landing thud.

@export_group("Dodge")
@export var dash_speed := 10.0
@export var dash_duration := 0.32
@export var dash_cooldown := 0.35 ## Seconds from the start of one dodge until the next is allowed.
@export var dash_cost := 20.0
@export var dodge_iframes := 0.25 ## Seconds of invincibility from the start of a dodge.
@export var dash_fov_kick := 8.0 ## Degrees the camera FOV widens during a forward/back dodge.
@export var dash_tilt := 6.0 ## Degrees the camera rolls toward a sideways dodge.

@export_group("Impact Feel")
@export var hitstop_min := 0.04 ## Seconds of hit-stop for the lightest hit...
@export var hitstop_max := 0.12 ## ...and for the heaviest.
@export var hitstop_time_scale := 0.05
@export var shake_min := 0.01 ## Camera shake (meters) for the lightest hit...
@export var shake_max := 0.04 ## ...and for the heaviest.
@export var pistol_shake := 0.03
@export var parry_hitstop := 0.15
@export var parry_shake := 0.05
@export var hurt_hitstop := 0.06
@export var hurt_shake := 0.06
@export var shake_decay := 14.0
@export var death_text_delay := 0.8 ## Seconds after dying before "YOU DIED" starts fading in.
@export var death_text_hold := 2.0 ## Seconds "YOU DIED" stays fully visible.
@export var death_fade_time := 1.2 ## Seconds for the final fade to black before the level restarts.
## Health won back per point of melee damage dealt, out of what the pistol spent.
@export var reclaim_per_damage := 5.0

@export_group("Weapon Feel")
@export var sway_strength := 0.0012 ## Radians the weapons lag per pixel of mouse movement...
@export var sway_max := 0.07 ## ...up to this many radians.
@export var sway_smoothing := 14.0 ## How quickly weapons follow the sway (higher is snappier).
@export var sway_return := 8.0 ## How quickly the sway settles back to center.
@export var bob_amount := 0.012 ## Meters the weapons bob while walking.
@export var camera_bob := 0.025 ## Meters the camera dips each step. 0 disables it.
@export var idle_breath := 0.004 ## Meters the weapons drift while standing.
@export var land_dip := 0.05 ## Meters the view dips on landing from a fall.
@export var low_health_threshold := 0.35 ## Below this fraction of max health, the screen edges pulse red.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var sword: Sword = $Head/Camera3D/Sword
@onready var pistol: Pistol = $Head/Camera3D/Pistol
@onready var flask: Flask = $Head/Camera3D/Flask
@onready var stamina: Stamina = $Stamina
@onready var health: Health = $Health
@onready var damage_flash: ColorRect = $HUD/DamageFlash
@onready var flask_icons: Control = $HUD/FlaskCharges
@onready var message_label: Label = $HUD/Message
@onready var crosshair: ColorRect = $HUD/Crosshair
@onready var vignette: ColorRect = $HUD/Vignette
@onready var death_fade: ColorRect = $HUD/DeathFade
@onready var death_text: Label = $HUD/DeathFade/DeathText
@onready var banner: Control = $HUD/Banner
@onready var banner_label: Label = $HUD/Banner/Text

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## A lunge is a short burst of forced, flat movement (dodges, sword lunges).
var _lunge_velocity := Vector3.ZERO
var _lunge_time_left := 0.0
var _lunge_exit_speed := INF ## Horizontal speed is capped to this when the lunge ends.
var _dash_cooldown_left := 0.0
var _base_fov: float
var _camera_tween: Tween
var _shake := 0.0
var _hitstop_until_msec := 0
var _iframes_left := 0.0
var _flash_tween: Tween
var _message_tween: Tween
var _step_distance := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _sway_target := Vector2.ZERO
var _sway := Vector2.ZERO
var _bob_phase := 0.0
var _bob_weight := 0.0
var _land_offset := 0.0
var _time := 0.0
var _camera_base_y := 0.0
var _weapon_rests: Array[Dictionary] = [] ## {node, position, rotation} for each held item.
var _crosshair_tween: Tween
var _crosshair_color: Color


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_fov = camera.fov
	sword.stamina = stamina
	pistol.stamina = stamina
	pistol.health = health
	sword.lunge_requested.connect(_on_sword_lunge_requested)
	sword.hit_landed.connect(_on_sword_hit_landed)
	pistol.fired.connect(func() -> void: _add_shake(pistol_shake))
	pistol.parried.connect(_on_pistol_parried)
	health.died.connect(_on_died)
	flask.drank.connect(_on_flask_drank)
	flask.finished.connect(func() -> void: pistol.visible = true)
	flask.charges_changed.connect(_update_flask_icons)
	_update_flask_icons(flask.charges)
	pistol.target_hit.connect(_show_hit_marker)

	_camera_base_y = camera.position.y
	for item: Node3D in [sword, pistol, flask]:
		_weapon_rests.append({ "node": item, "position": item.position, "rotation": item.rotation })
	_crosshair_color = crosshair.color
	crosshair.pivot_offset = crosshair.size * 0.5
	death_text.pivot_offset = death_text.size * 0.5
	banner_label.pivot_offset = banner_label.size * 0.5


func is_dead() -> bool:
	return health.is_dead()


## True during a sword windup or strike. Enemies use this to react.
func is_attack_committed() -> bool:
	return sword.is_committed()


func grant_max_health(amount: float) -> void:
	health.increase_max(amount)
	_flash_screen(Color(1.0, 0.85, 0.4, 0.25), 0.8)


## Shows a line of text near the bottom of the screen for a few seconds.
func show_message(text: String) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.3)
	_message_tween.tween_interval(2.5)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.8)


func take_hit(damage: int, impulse: Vector3) -> void:
	if is_dead() or _iframes_left > 0.0:
		return
	# Flash first: a fatal hit's death fade (in _on_died) takes over from it.
	_flash_screen(Color(0.6, 0.0, 0.0, 0.35), 0.4)
	Audio.play("player_hurt")
	health.damage(damage)
	velocity += Vector3(impulse.x, 0.0, impulse.z)
	_hitstop(hurt_hitstop)
	_add_shake(hurt_shake)


func _exit_tree() -> void:
	Engine.time_scale = 1.0 # Don't leave the game slowed if freed mid hit-stop.


func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative ignores the window stretch scale, so sensitivity
		# stays consistent regardless of window size.
		var delta: Vector2 = event.screen_relative
		rotate_y(-delta.x * mouse_sensitivity)
		head.rotate_x(-delta.y * mouse_sensitivity)
		var max_pitch := deg_to_rad(max_pitch_degrees)
		head.rotation.x = clampf(head.rotation.x, -max_pitch, max_pitch)
		# Weapons lag behind the turn.
		_sway_target = (_sway_target + delta * sway_strength).clamp(
				Vector2(-sway_max, -sway_max), Vector2(sway_max, sway_max))
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# This click only recaptures the mouse; it shouldn't also attack.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("attack"):
		if not flask.is_using():
			sword.press()
	elif event.is_action_released("attack"):
		sword.release()
	elif event.is_action_pressed("shoot"):
		if not flask.is_using():
			pistol.fire()
	elif event.is_action_pressed("heal"):
		_try_drink()


func _process(delta: float) -> void:
	# Hit-stop is timed in real time, since it slows the game clock itself.
	if Engine.time_scale != 1.0 and Time.get_ticks_msec() >= _hitstop_until_msec:
		Engine.time_scale = 1.0

	if _shake > 0.0005:
		camera.h_offset = randf_range(-_shake, _shake)
		camera.v_offset = randf_range(-_shake, _shake)
		_shake *= exp(-shake_decay * delta)
	elif _shake > 0.0:
		_shake = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	_update_weapon_feel(delta)
	_update_vignette()


## Weapon sway (lagging behind the mouse), walking bob, idle breathing, and
## the dip on landing, applied on top of each held item's resting pose.
func _update_weapon_feel(delta: float) -> void:
	_time += delta
	_sway_target = _sway_target.lerp(Vector2.ZERO, 1.0 - exp(-sway_return * delta))
	_sway = _sway.lerp(_sway_target, 1.0 - exp(-sway_smoothing * delta))
	_land_offset = lerpf(_land_offset, 0.0, 1.0 - exp(-8.0 * delta))

	var speed := Vector2(velocity.x, velocity.z).length()
	var walking := is_on_floor() and speed > 0.5 and _lunge_time_left <= 0.0 and not is_dead()
	_bob_weight = move_toward(_bob_weight, clampf(speed / walk_speed, 0.0, 1.0) if walking else 0.0, delta * 4.0)
	if walking:
		_bob_phase += speed * delta / step_length * PI # Half a cycle per step: one dip per footstep.

	var step_dip := absf(sin(_bob_phase))
	var bob := Vector3(cos(_bob_phase) * bob_amount, -step_dip * bob_amount * 1.4, 0.0) * _bob_weight
	bob.y += sin(_time * 1.6) * idle_breath + _land_offset
	var lag := Vector3(-_sway.x, _sway.y, 0.0) * 0.15
	var tilt := Vector3(_sway.y, _sway.x, _sway.x * 0.5)
	for rest in _weapon_rests:
		var item: Node3D = rest.node
		item.position = rest.position + bob + lag
		item.rotation = rest.rotation + tilt

	camera.position.y = _camera_base_y - step_dip * camera_bob * _bob_weight + _land_offset * 0.5


## Darkens the screen edges, and pulses them red at low health.
func _update_vignette() -> void:
	var ratio := health.value / health.max_value
	var danger := clampf((low_health_threshold - ratio) / (low_health_threshold * 0.7), 0.0, 1.0)
	if is_dead():
		danger = 1.0
	var pulse := 0.75 + 0.25 * sin(_time * 4.0)
	(vignette.material as ShaderMaterial).set_shader_parameter("danger", danger * pulse)


## Flashes the crosshair red and pops it bigger, confirming a hit.
func _show_hit_marker() -> void:
	if _crosshair_tween:
		_crosshair_tween.kill()
	crosshair.color = Color(1.0, 0.25, 0.2, 1.0)
	crosshair.scale = Vector2.ONE * 2.2
	_crosshair_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_crosshair_tween.tween_property(crosshair, "scale", Vector2.ONE, 0.18)
	_crosshair_tween.parallel().tween_property(crosshair, "color", _crosshair_color, 0.25)


func _physics_process(delta: float) -> void:
	_iframes_left = maxf(_iframes_left - delta, 0.0)
	if is_dead():
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	# Attacks and drinks are committed: no dodging out of them.
	if Input.is_action_just_pressed("dash") and _dash_cooldown_left == 0.0 \
			and not sword.is_committed() and not flask.is_using() \
			and stamina.try_spend(dash_cost):
		_start_dash(input)

	if _lunge_time_left > 0.0:
		# Lunges are flat and ignore gravity. Afterwards the normal movement
		# below bleeds off any remaining extra speed.
		_lunge_time_left -= delta
		velocity = _lunge_velocity
		move_and_slide()
		if _lunge_time_left <= 0.0:
			velocity = velocity.limit_length(_lunge_exit_speed)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var target := direction * walk_speed
	if sword.is_attacking() or flask.is_using():
		target *= attack_move_multiplier

	# Smoothly approach the target horizontal velocity; vertical is left to gravity.
	var weight := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	_fall_speed = maxf(-velocity.y, 0.0)
	move_and_slide()
	_update_footsteps(delta)


func _update_footsteps(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed > land_sound_speed:
		Audio.play("footstep_land")
		_step_distance = 0.0
		_land_offset = -land_dip * clampf(_fall_speed / 8.0, 0.5, 1.5)
	_was_on_floor = on_floor
	if not on_floor:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		_step_distance = step_length * 0.6 # The first step after stopping comes quickly.
		return
	_step_distance += speed * delta
	if _step_distance >= step_length:
		_step_distance -= step_length
		Audio.play("footstep")


func _start_dash(input: Vector2) -> void:
	sword.cancel_charge() # Dodging out of a charge abandons it.

	var local_direction := Vector3(input.x, 0.0, input.y).normalized()
	if local_direction == Vector3.ZERO:
		local_direction = Vector3.FORWARD
	# Dodges keep their momentum and ease out.
	_lunge(transform.basis * local_direction * dash_speed, dash_duration, INF)
	_dash_cooldown_left = dash_cooldown
	_iframes_left = dodge_iframes
	Audio.play("dodge")

	# Forward/back dodges widen the FOV; sideways dodges roll the camera
	# toward the dodge. Diagonals get a blend of both.
	var target_fov := _base_fov + dash_fov_kick * absf(local_direction.z)
	var target_roll := deg_to_rad(-dash_tilt * local_direction.x)

	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(camera, "fov", target_fov, dash_duration * 0.5).set_ease(Tween.EASE_OUT)
	_camera_tween.parallel().tween_property(camera, "rotation:z", target_roll, dash_duration * 0.5).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "fov", _base_fov, 0.3).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.parallel().tween_property(camera, "rotation:z", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT)


func _lunge(lunge_velocity: Vector3, duration: float, exit_speed: float) -> void:
	_lunge_velocity = lunge_velocity
	_lunge_time_left = duration
	_lunge_exit_speed = exit_speed


func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _hitstop(duration: float) -> void:
	Engine.time_scale = hitstop_time_scale
	_hitstop_until_msec = maxi(_hitstop_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))


func _on_sword_lunge_requested(distance: float, duration: float) -> void:
	# Stop crisply at walking speed so the lunge covers about the requested distance.
	_lunge(-transform.basis.z * distance / duration, duration, walk_speed)


func _on_sword_hit_landed(impact: float, damage_dealt: int) -> void:
	if damage_dealt > 0:
		_show_hit_marker()
	_hitstop(lerpf(hitstop_min, hitstop_max, impact))
	_add_shake(lerpf(shake_min, shake_max, impact))
	health.reclaim(damage_dealt * reclaim_per_damage)


func _try_drink() -> void:
	# Can't drink mid-attack or mid-dodge, and there's no point at full health.
	if flask.is_using() or sword.is_attacking() or _lunge_time_left > 0.0 or health.is_full():
		return
	if flask.use():
		pistol.visible = false # The off hand holds the flask instead.


func _on_flask_drank() -> void:
	health.heal(health.max_value * flask.heal_fraction)
	_flash_screen(Color(1.0, 0.7, 0.3, 0.2), 0.6)


func _update_flask_icons(charges: int) -> void:
	for i in flask_icons.get_child_count():
		var icon: CanvasItem = flask_icons.get_child(i)
		icon.modulate.a = 1.0 if i < charges else 0.2


func _flash_screen(color: Color, duration: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	damage_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, duration)


func _on_pistol_parried() -> void:
	_hitstop(parry_hitstop)
	_add_shake(parry_shake)
	Audio.play("parry")


func _on_died() -> void:
	sword.cancel_charge()
	Audio.play("player_death")
	# Collapse to the ground, then restart the level.
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_camera_tween.tween_property(head, "position:y", 0.3, 0.8)
	_camera_tween.parallel().tween_property(camera, "rotation:z", deg_to_rad(70.0), 0.8)
	if _flash_tween:
		_flash_tween.kill()
	damage_flash.color = Color(0.6, 0.0, 0.0, damage_flash.color.a)
	_camera_tween.parallel().tween_property(damage_flash, "color:a", 0.5, 0.8)

	# "YOU DIED" fades in as the screen darkens, holds, then all goes black.
	death_text.scale = Vector2.ONE * 0.92
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_interval(death_text_delay)
	tween.tween_property(death_text, "modulate:a", 1.0, 1.5)
	tween.parallel().tween_property(death_text, "scale", Vector2.ONE, 3.0).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(death_fade, "color:a", 0.6, 1.5)
	tween.tween_interval(death_text_hold)
	tween.tween_property(death_fade, "color:a", 1.0, death_fade_time)
	tween.parallel().tween_property(death_text, "modulate:a", 0.0, death_fade_time)
	tween.tween_callback(_respawn)


## Shows large centered text, like a boss victory announcement.
func show_banner(text: String, color: Color, hold := 3.0) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_label.scale = Vector2.ONE * 0.95
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(banner, "modulate:a", 1.0, 1.2)
	tween.parallel().tween_property(banner_label, "scale", Vector2.ONE, 4.0).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_property(banner, "modulate:a", 0.0, 1.5)


func _respawn() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false # In case the pause menu was open when the timer ran out.
	get_tree().reload_current_scene()
