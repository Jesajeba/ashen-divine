class_name Stamina
extends Node
## Stamina pool shared by the player's actions.
##
## Souls-style rules: an action is allowed as long as there is any stamina
## left, even if it costs more than remains (stamina then bottoms out at 0).
## Spending pauses regeneration for regen_delay seconds.

signal changed(value: float, max_value: float)
## Emitted when an action is refused because stamina is empty.
signal exhausted

@export var max_value := 100.0
@export var regen_rate := 35.0 ## Per second.
@export var regen_delay := 0.8 ## Seconds after spending before regeneration resumes.

var value: float

var _regen_wait := 0.0


func _ready() -> void:
	value = max_value


func _process(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	if value < max_value:
		value = minf(value + regen_rate * delta, max_value)
		changed.emit(value, max_value)


func has_any() -> bool:
	return value > 0.0


## Spends cost if any stamina is left. Returns whether the action may happen.
func try_spend(cost: float) -> bool:
	if not has_any():
		exhausted.emit()
		return false
	value = maxf(value - cost, 0.0)
	_regen_wait = regen_delay
	changed.emit(value, max_value)
	return true


## Keeps regeneration paused, e.g. while charging an attack.
func hold_regen() -> void:
	_regen_wait = maxf(_regen_wait, regen_delay)
