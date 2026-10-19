##
## std/input/motion_filter.gd
##
## A filter which sums pointer motion over a sliding wall-clock window and reports
## whether the sum exceeds a per-axis minimum. `StdInputCursor` uses it to decide when
## motion reveals the cursor, and the Steam actions component uses it to decide when an
## "absolute mouse" action counts as joypad activity, so both apply one threshold to
## what deliberate pointing is.
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

## minimum is the distance, per axis in screen pixels, which summed motion must exceed
## on at least one axis.
var minimum: Vector2 = Vector2.ZERO

## window is the duration (in seconds) over which signed motion is summed before it's
## compared to `minimum`; `0` compares each motion on its own.
var window: float = 0.0

var _deltas := PackedVector2Array()
var _times := PackedInt64Array()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear drops the motion summed so far.
func clear() -> void:
	_deltas = PackedVector2Array()
	_times = PackedInt64Array()


## configure sets the threshold to the largest `cursor_reveal_distance_minimum` and
## `cursor_reveal_window` across the provided action sets. Summed motion is dropped only
## when the threshold changes, so this may be called repeatedly.
func configure(action_sets: Array[StdInputActionSet]) -> void:
	var next_minimum: Vector2 = action_sets.reduce(
		func(v, s): return v.max(s.cursor_reveal_distance_minimum), Vector2.ZERO
	)
	var next_window: float = action_sets.reduce(
		func(w, s): return max(w, s.cursor_reveal_window), 0.0
	)

	if next_minimum == minimum and next_window == window:
		return

	minimum = next_minimum
	window = next_window

	clear()


## exceeds_minimum returns whether `motion` exceeds `minimum` on either axis.
func exceeds_minimum(motion: Vector2) -> bool:
	# NOTE: Each axis is compared on its own, since `Vector2`'s `>` compares the y
	# components only when the x components are equal.
	return absf(motion.x) > minimum.x or absf(motion.y) > minimum.y


## push records `relative`, a pointer motion in screen pixels, and returns whether the
## motion exceeds `minimum` on either axis. With a `window`, the signed motion within
## the window is summed first, so the minimum acts as a speed instead of a per-event
## distance and back-and-forth jitter cancels out.
func push(relative: Vector2) -> bool:
	if window <= 0.0:
		return exceeds_minimum(relative)

	# NOTE: Ticks are wall clock time, so neither `Engine.time_scale` nor a paused tree
	# stretches the window.
	var now := Time.get_ticks_usec()
	var cutoff := now - int(window * 1_000_000.0)

	var expired := 0
	while expired < _times.size() and _times[expired] < cutoff:
		expired += 1

	if expired > 0:
		_deltas = _deltas.slice(expired)
		_times = _times.slice(expired)

	_deltas.append(relative)
	_times.append(now)

	var total := Vector2.ZERO
	for delta in _deltas:
		total += delta

	return exceeds_minimum(total)
