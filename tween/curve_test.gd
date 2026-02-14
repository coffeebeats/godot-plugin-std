##
## tween/curve_test.gd
##
## Tests pertaining to the 'StdTweenCurve' class.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_curve_new_has_expected_defaults():
	# Given: A new StdTweenCurve instance.
	var curve := StdTweenCurve.new()

	# Then: The default values match expectations.
	assert_eq(curve.delay, 0.0)
	assert_eq(curve.duration, 0.0)
	assert_eq(curve.ease_type, Tween.EASE_OUT)
	assert_eq(curve.transition_type, Tween.TRANS_EXPO)


func test_tween_property_creates_tweener_and_animates():
	# Given: A curve with non-default settings and a target node.
	var curve := StdTweenCurve.new()
	curve.duration = 0.05
	curve.ease_type = Tween.EASE_IN
	curve.transition_type = Tween.TRANS_LINEAR

	var node := Node2D.new()
	add_child_autofree(node)

	# When: A property tweener is created via the curve.
	var tween := create_tween()
	var tweener := curve.tween_property(tween, node, ^"position:x", 100.0)

	# Then: A tweener is returned and the animation completes.
	assert_not_null(tweener)
	await wait_for_signal(tween.finished, 1.0)
	assert_almost_eq(node.position.x, 100.0, 0.1)


func test_tween_property_uses_duration_override():
	# Given: A curve with a long duration and a target node.
	var curve := StdTweenCurve.new()
	curve.duration = 10.0
	curve.ease_type = Tween.EASE_IN
	curve.transition_type = Tween.TRANS_LINEAR

	var node := Node2D.new()
	add_child_autofree(node)

	# When: A property tweener is created with a short duration override.
	var tween := create_tween()
	curve.tween_property(tween, node, ^"position:x", 100.0, 0.05)

	# Then: The animation completes quickly using the override duration.
	await wait_for_signal(tween.finished, 1.0)
	assert_almost_eq(node.position.x, 100.0, 0.1)


func test_tween_property_with_zero_duration_override():
	# Given: A curve with a non-zero duration and a target node.
	var curve := StdTweenCurve.new()
	curve.duration = 10.0
	curve.transition_type = Tween.TRANS_LINEAR

	var node := Node2D.new()
	add_child_autofree(node)

	# When: A property tweener is created with a zero duration override.
	var tween := create_tween()
	curve.tween_property(tween, node, ^"position:x", 100.0, 0.0)

	# Then: The animation completes immediately.
	await wait_for_signal(tween.finished, 1.0)
	assert_almost_eq(node.position.x, 100.0, 0.1)
