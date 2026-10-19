##
## Tests pertaining to the `MotionFilter` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const MotionFilter := preload("motion_filter.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var filter: MotionFilter = null

# -- TEST METHODS -------------------------------------------------------------------- #


func before_each() -> void:
	filter = MotionFilter.new()


func test_motion_filter_push_without_window_compares_each_motion_alone() -> void:
	# Given: A filter with a minimum of (4, 4) and no window.
	filter.minimum = Vector2(4, 4)

	# When: Three motions within the minimum are pushed.
	var results := [
		filter.push(Vector2(3, 0)),
		filter.push(Vector2(3, 0)),
		filter.push(Vector2(3, 0)),
	]

	# Then: None exceeds the minimum.
	assert_eq(results, [false, false, false])


func test_motion_filter_push_exceeds_minimum_on_either_axis() -> void:
	# Given: A filter with a minimum of (4, 4) and no window.
	filter.minimum = Vector2(4, 4)

	# Then: Motion past the minimum on one axis exceeds it, and equal motion doesn't.
	assert_true(filter.push(Vector2(5, 0)))
	assert_true(filter.push(Vector2(0, 5)))
	assert_false(filter.push(Vector2(4, 4)))


func test_motion_filter_push_with_window_sums_motion() -> void:
	# Given: A filter with a minimum of (4, 4) summed over one second.
	filter.minimum = Vector2(4, 4)
	filter.window = 1.0

	# When: Three motions within the minimum are pushed.
	var results := [
		filter.push(Vector2(2, 0)),
		filter.push(Vector2(2, 0)),
		filter.push(Vector2(2, 0)),
	]

	# Then: Only the motion which brings the sum past the minimum exceeds it.
	assert_eq(results, [false, false, true])


func test_motion_filter_push_with_window_cancels_opposing_motion() -> void:
	# Given: A filter with a minimum of (4, 4) summed over one second.
	filter.minimum = Vector2(4, 4)
	filter.window = 1.0

	# When: Motions which reverse direction are pushed.
	var results := [
		filter.push(Vector2(3, 0)),
		filter.push(Vector2(-3, 0)),
		filter.push(Vector2(3, 0)),
	]

	# Then: None exceeds the minimum.
	assert_eq(results, [false, false, false])


func test_motion_filter_push_with_window_drops_expired_motion() -> void:
	# Given: A filter with a minimum of (4, 4) summed over 50 ms.
	filter.minimum = Vector2(4, 4)
	filter.window = 0.05

	# Given: A motion within the minimum, aged past the window.
	filter.push(Vector2(3, 0))
	var times := filter._times
	times[0] -= 100_000
	filter._times = times

	# When: Another motion within the minimum is pushed.
	var exceeded := filter.push(Vector2(3, 0))

	# Then: The sum doesn't exceed the minimum.
	assert_false(exceeded)


func test_motion_filter_clear_drops_summed_motion() -> void:
	# Given: A filter with a minimum of (4, 4) summed over one second, with motion.
	filter.minimum = Vector2(4, 4)
	filter.window = 1.0
	filter.push(Vector2(3, 0))

	# When: The filter is cleared.
	filter.clear()

	# Then: Another motion within the minimum doesn't exceed it.
	assert_false(filter.push(Vector2(3, 0)))


func test_motion_filter_configure_uses_largest_threshold_across_sets() -> void:
	# Given: Two action sets with different reveal thresholds.
	var first := StdInputActionSet.new()
	first.cursor_reveal_distance_minimum = Vector2(4, 2)
	first.cursor_reveal_window = 0.2
	var second := StdInputActionSet.new()
	second.cursor_reveal_distance_minimum = Vector2(2, 6)
	second.cursor_reveal_window = 0.5

	# When: The filter is configured with both.
	filter.configure([first, second])

	# Then: The largest minimum per axis and the longest window are used.
	assert_eq(filter.minimum, Vector2(4, 6))
	assert_eq(filter.window, 0.5)


func test_motion_filter_configure_keeps_summed_motion_when_unchanged() -> void:
	# Given: A filter configured to sum motion against (4, 4), with motion.
	var action_set := StdInputActionSet.new()
	action_set.cursor_reveal_distance_minimum = Vector2(4, 4)
	action_set.cursor_reveal_window = 1.0
	filter.configure([action_set])
	filter.push(Vector2(3, 0))

	# When: The filter is configured with the same threshold again.
	filter.configure([action_set])

	# Then: The earlier motion still counts toward the sum.
	assert_true(filter.push(Vector2(3, 0)))


func test_motion_filter_configure_clears_summed_motion_when_changed() -> void:
	# Given: A filter configured to sum motion against (4, 4), with motion.
	var action_set := StdInputActionSet.new()
	action_set.cursor_reveal_distance_minimum = Vector2(4, 4)
	action_set.cursor_reveal_window = 1.0
	filter.configure([action_set])
	filter.push(Vector2(3, 0))

	# When: The filter is configured with a different minimum.
	var changed := StdInputActionSet.new()
	changed.cursor_reveal_distance_minimum = Vector2(5, 5)
	changed.cursor_reveal_window = 1.0
	filter.configure([changed])

	# Then: The earlier motion no longer counts toward the sum.
	assert_false(filter.push(Vector2(3, 0)))
