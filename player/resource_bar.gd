extends Control
## Souls-style HUD bar for a value like health or stamina. The fill drops
## immediately when the value falls, while a pale trail lingers behind it for
## a moment before catching up.
##
## The source node needs `value` and `max_value` properties and a
## `changed(value, max_value)` signal. If it also has an `exhausted` signal,
## the border flashes red when it fires. If it has a `reclaimable` property
## (like Health), that amount is shown just past the fill, pulsing shortly
## before it starts to drain if the source has reclaim_hold_left().

@export var source: Node
@export var fill_color := Color(0.27, 0.62, 0.3)
@export var trail_color := Color(0.92, 0.85, 0.55)
@export var reclaim_color := Color(0.95, 0.5, 0.15, 0.8)
@export var reclaim_warning_time := 1.5 ## Pulse the reclaimable part this long before it drains.
## If above 0, the bar's width follows max_value (pixels per point), so it
## grows when max_value is raised. Otherwise it keeps its laid-out width.
@export var width_per_point := 0.0
@export var back_color := Color(0.0, 0.0, 0.0, 0.55)
@export var border_color := Color(1.0, 1.0, 1.0, 0.25)
@export var exhausted_color := Color(0.9, 0.2, 0.15)
@export var trail_delay := 0.45 ## Seconds the trail lingers before shrinking.
@export var trail_speed := 80.0 ## Value per second the trail shrinks by.

var _shown := 0.0
var _trail := 0.0
var _trail_wait := 0.0
var _flash := 0.0
var _max := 1.0
var _reclaimable := 0.0


func _ready() -> void:
	if not source:
		push_warning("%s has no source assigned." % name)
		return
	source.connect("changed", _on_source_changed)
	if source.has_signal("exhausted"):
		source.connect("exhausted", _on_source_exhausted)
	# The source may not have initialized yet, so read its values next frame.
	_sync.call_deferred()


func _process(delta: float) -> void:
	if _trail > _shown:
		if _trail_wait > 0.0:
			_trail_wait -= delta
		else:
			_trail = maxf(_trail - trail_speed * delta, _shown)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.0, 0.0)
		queue_redraw()
	if _reclaimable > 0.0:
		queue_redraw() # Keeps the warning pulse animating.


func _draw() -> void:
	var inner := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var px_per_point := inner.size.x / _max
	draw_rect(Rect2(Vector2.ZERO, size), back_color)
	if _reclaimable > 0.0:
		var color := reclaim_color
		if source.has_method("reclaim_hold_left"):
			var hold_left: float = source.call("reclaim_hold_left")
			if hold_left < reclaim_warning_time:
				color.a *= 0.55 + 0.45 * cos(Time.get_ticks_msec() / 1000.0 * 12.0)
		draw_rect(Rect2(inner.position + Vector2(_shown * px_per_point, 0.0),
				Vector2(_reclaimable * px_per_point, inner.size.y)), color)
	draw_rect(Rect2(inner.position, Vector2(_trail * px_per_point, inner.size.y)), trail_color)
	draw_rect(Rect2(inner.position, Vector2(_shown * px_per_point, inner.size.y)), fill_color)
	draw_rect(Rect2(Vector2.ZERO, size), border_color.lerp(exhausted_color, _flash), false, 1.0 + _flash)


func _sync() -> void:
	_set_max(source.get("max_value"))
	_shown = source.get("value")
	_trail = _shown
	_read_reclaimable()
	queue_redraw()


func _read_reclaimable() -> void:
	var reclaimable: Variant = source.get("reclaimable")
	_reclaimable = reclaimable if reclaimable != null else 0.0


func _set_max(max_value: float) -> void:
	_max = maxf(max_value, 0.001)
	if width_per_point > 0.0:
		size.x = _max * width_per_point + 4.0 # Plus the 2px border on each side.


func _on_source_changed(value: float, max_value: float) -> void:
	_set_max(max_value)
	if value < _shown:
		_trail = maxf(_trail, _shown)
		_trail_wait = trail_delay
	else:
		_trail = maxf(_trail, value)
	_shown = value
	_read_reclaimable()
	queue_redraw()


func _on_source_exhausted() -> void:
	_flash = 1.0
	queue_redraw()
