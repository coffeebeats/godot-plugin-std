##
## screen/transitions/fade_test.gd
##
## Tests pertaining to the 'StdScreenTransitionFade' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Context := preload("../context.gd")
const Controller := preload("../manager/controller.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class MockManager:
	extends Node

	signal transition_done

	func _get_current_overlay() -> Node:
		return null

	func _on_transitions_settled() -> void:
		pass


# -- INITIALIZATION ------------------------------------------------------------------ #

var _mock: MockManager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_exit_fade_tweens_overlay_to_opaque():
	# Given: A fade transition and a scene under the manager.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: An exit fade is started.
	_start_fade(fade, scene, false)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The overlay is opaque.
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_almost_eq(overlay.modulate.a, 1.0, 0.01)


func test_enter_fade_tweens_overlay_to_transparent():
	# Given: A fade transition with an opaque overlay already present.
	var fade := _create_fade()
	var scene := _create_scene()
	var overlay := _ensure_overlay(1.0)

	# When: An enter fade is started.
	_start_fade(fade, scene, true)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The overlay is transparent.
	assert_almost_eq(overlay.modulate.a, 0.0, 0.01)


func test_fade_invokes_done_on_finish():
	# Given: A fade transition.
	var fade := _create_fade()
	var scene := _create_scene()
	watch_signals(_mock)

	# When: An exit fade runs to completion.
	_start_fade(fade, scene, false)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The done callback was invoked exactly once.
	assert_signal_emit_count(_mock, "transition_done", 1)


func test_stop_preserves_overlay_alpha():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()

	# When: An exit fade is started and stopped mid-way.
	_start_fade(fade, scene, false)
	await wait_process_frames(2)
	fade.stop()

	# Then: The overlay alpha is between 0 and 1.
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_gt(overlay.modulate.a, 0.0)
	assert_lt(overlay.modulate.a, 1.0)


func test_reset_frees_overlay_and_removes_metadata():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()

	# When: An exit fade is started and reset mid-way.
	_start_fade(fade, scene, false)
	await wait_process_frames(2)
	var overlay := _get_overlay()
	assert_not_null(overlay)
	fade.reset()
	await wait_physics_frames(2)

	# Then: The overlay is freed and metadata is removed.
	assert_false(is_instance_valid(overlay))
	assert_null(_get_overlay())


func test_overlay_shared_across_transitions():
	# Given: Two fade transitions on the same manager.
	var fade_a := _create_fade()
	var fade_b := _create_fade()
	var scene := _create_scene()

	# When: Both transitions run.
	_start_fade(fade_a, scene, false)
	await wait_for_signal(_mock.transition_done, 2.0)

	_start_fade(fade_b, scene, true)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: Both used the same overlay instance.
	assert_same(fade_a._overlay, fade_b._overlay)


func test_overlay_color_updates_on_start():
	# Given: A fade transition with a custom color.
	var fade := _create_fade()
	fade.color = Color.RED
	var scene := _create_scene()

	# When: The fade starts.
	_start_fade(fade, scene, false)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The overlay color matches.
	var overlay := _get_overlay()
	assert_eq(overlay.color, Color.RED)


func test_stop_does_not_invoke_done():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()
	watch_signals(_mock)

	# When: The fade is started and stopped.
	_start_fade(fade, scene, false)
	await wait_process_frames(2)
	fade.stop()
	await wait_physics_frames(2)

	# Then: The done callback was not invoked.
	assert_signal_not_emitted(_mock, "transition_done")


func test_reset_does_not_invoke_done():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()
	watch_signals(_mock)

	# When: The fade is started and reset.
	_start_fade(fade, scene, false)
	await wait_process_frames(2)
	fade.reset()
	await wait_physics_frames(2)

	# Then: The done callback was not invoked.
	assert_signal_not_emitted(_mock, "transition_done")


func test_overlay_mouse_filter_is_ignore():
	# Given: A fade transition.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: The fade starts (creating the overlay).
	_start_fade(fade, scene, false)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The overlay does not intercept mouse input.
	var overlay := _get_overlay()
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_fade_uses_proportional_duration():
	# Given: A fade with a 0.2s duration and an overlay already at 0.5 alpha.
	var fade := _create_fade()
	fade.duration = 0.2
	var scene := _create_scene()
	_ensure_overlay(0.5)

	# When: An enter fade is started (target 0.0, remaining 0.5).
	var start_time := Time.get_ticks_msec()
	_start_fade(fade, scene, true)
	await wait_for_signal(_mock.transition_done, 2.0)
	var elapsed := Time.get_ticks_msec() - start_time

	# Then: The fade completes in roughly half the configured duration.
	assert_lt(elapsed, 180)


func test_fade_reuse_after_stop():
	# Given: A fade transition that has been started and stopped.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()

	_start_fade(fade, scene, false)
	await wait_process_frames(2)
	fade.stop()

	# When: The same fade resource is started again.
	fade.duration = 0.01
	_start_fade(fade, scene, true)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The second fade completes successfully.
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_almost_eq(overlay.modulate.a, 0.0, 0.01)


func test_fade_with_zero_duration():
	# Given: A fade transition with zero duration.
	var fade := _create_fade()
	fade.duration = 0.0
	var scene := _create_scene()
	watch_signals(_mock)

	# When: An exit fade is started.
	_start_fade(fade, scene, false)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The fade completes and the overlay reaches the target.
	assert_signal_emitted(_mock, "transition_done")
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_almost_eq(overlay.modulate.a, 1.0, 0.01)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	_mock = MockManager.new()
	_mock.name = &"TestManager"
	add_child_autofree(_mock)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_context() -> Context:
	return Context.new(_mock, Controller.new(_mock))


func _create_fade() -> StdScreenTransitionFade:
	var fade := StdScreenTransitionFade.new()
	fade.duration = 0.01
	return fade


func _create_scene() -> Control:
	var scene := Control.new()
	_mock.add_child(scene)
	return scene


func _ensure_overlay(alpha: float) -> ColorRect:
	var ctx := _create_context()
	var overlay := _create_fade()._get_or_create_overlay(ctx)
	overlay.modulate.a = alpha
	autofree(overlay)
	return overlay


func _get_overlay() -> ColorRect:
	var key := &"_std_fade_overlay"
	if _mock.has_meta(key):
		return _mock.get_meta(key)
	return null


func _start_fade(
	fade: StdScreenTransitionFade,
	scene: Node,
	is_entering: bool,
) -> void:
	var ctx := _create_context()
	ctx._on_done = _mock.transition_done.emit
	fade.start(ctx, scene, is_entering)
	var overlay := _get_overlay()
	if overlay:
		autofree(overlay)
