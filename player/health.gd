class_name Health
extends Node
## Hit points. Emits died once when they reach zero.
##
## Health can also be spent on actions (spend()). Spent health is lost right
## away but stays reclaimable: reclaim() wins it back, up to the amount spent.
## Taking damage doesn't touch the reclaimable amount, beyond capping it to
## what's missing.
##
## Reclaimable health is held for reclaim_decay_delay seconds, then drains
## away. Spending more or reclaiming some restarts the countdown, so staying
## aggressive keeps it alive.

signal changed(value: float, max_value: float)
signal died
## Emitted when spend() is refused because it would be fatal.
signal exhausted

@export var max_value := 100.0
@export var reclaim_decay_delay := 4.0 ## Seconds after spending or reclaiming before reclaimable health starts draining.
@export var reclaim_decay_rate := 5.0 ## Reclaimable health lost per second. 0 keeps it until reclaimed.

var value: float
var reclaimable := 0.0

var _decay_wait := 0.0


func _ready() -> void:
	value = max_value


func _process(delta: float) -> void:
	if reclaim_decay_rate <= 0.0 or reclaimable <= 0.0:
		return
	if _decay_wait > 0.0:
		_decay_wait -= delta
		return
	reclaimable = maxf(reclaimable - reclaim_decay_rate * delta, 0.0)
	changed.emit(value, max_value)


## Seconds until reclaimable health starts draining (0 while draining,
## INF if it never drains).
func reclaim_hold_left() -> float:
	return maxf(_decay_wait, 0.0) if reclaim_decay_rate > 0.0 else INF


func is_dead() -> bool:
	return value <= 0.0


func damage(amount: float) -> void:
	if is_dead():
		return
	value = maxf(value - amount, 0.0)
	reclaimable = 0.0 if is_dead() else minf(reclaimable, max_value - value)
	changed.emit(value, max_value)
	if is_dead():
		died.emit()


func is_full() -> bool:
	return value >= max_value


## Permanently raises max health, filling the new capacity.
func increase_max(amount: float) -> void:
	max_value += amount
	if not is_dead():
		value += amount
	changed.emit(value, max_value)


func heal(amount: float) -> void:
	if is_dead():
		return
	value = minf(value + amount, max_value)
	reclaimable = minf(reclaimable, max_value - value)
	changed.emit(value, max_value)


## Spends health on an action, keeping it reclaimable. Refused (returning
## false) if it would leave no health.
func spend(amount: float) -> bool:
	if value <= amount:
		exhausted.emit()
		return false
	value -= amount
	reclaimable = minf(reclaimable + amount, max_value - value)
	_decay_wait = reclaim_decay_delay
	changed.emit(value, max_value)
	return true


## Restores up to amount of the reclaimable health.
func reclaim(amount: float) -> void:
	var gained := minf(amount, reclaimable)
	if gained <= 0.0 or is_dead():
		return
	value += gained
	reclaimable -= gained
	_decay_wait = reclaim_decay_delay
	changed.emit(value, max_value)
