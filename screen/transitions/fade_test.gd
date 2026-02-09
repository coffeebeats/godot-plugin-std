##
## screen/transitions/fade_test.gd
##
## Tests pertaining to the 'StdScreenTransitionFade' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Manager := preload("../manager.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_exit_fade_tweens_overlay_to_opaque():
	# Given: A fade transition and a scene under the manager.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: An exit fade is started.
	fade.start(_manager, scene, false)
	await wait_for_signal(fade.completed, 2.0)

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
	fade.start(_manager, scene, true)
	await wait_for_signal(fade.completed, 2.0)

	# Then: The overlay is transparent.
	assert_almost_eq(overlay.modulate.a, 0.0, 0.01)


func test_fade_emits_completed_on_finish():
	# Given: A fade transition.
	var fade := _create_fade()
	var scene := _create_scene()
	watch_signals(fade)

	# When: An exit fade runs to completion.
	fade.start(_manager, scene, false)
	await wait_for_signal(fade.completed, 2.0)

	# Then: The completed signal was emitted.
	assert_signal_emit_count(fade, "completed", 1)


func test_stop_preserves_overlay_alpha():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()

	# When: An exit fade is started and stopped mid-way.
	fade.start(_manager, scene, false)
	await wait_process_frames(2)
	fade.stop()

	# Then: The overlay alpha is between 0 and 1.
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_gt(overlay.modulate.a, 0.0)
	assert_lt(overlay.modulate.a, 1.0)


func test_reset_restores_overlay_alpha():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()

	# When: An exit fade is started and reset mid-way.
	fade.start(_manager, scene, false)
	await wait_process_frames(2)
	fade.reset()

	# Then: The overlay alpha is restored to transparent.
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_almost_eq(overlay.modulate.a, 0.0, 0.01)


func test_overlay_shared_across_transitions():
	# Given: Two fade transitions on the same manager.
	var fade_a := _create_fade()
	var fade_b := _create_fade()
	var scene := _create_scene()

	# When: Both transitions run.
	fade_a.start(_manager, scene, false)
	await wait_for_signal(fade_a.completed, 2.0)

	fade_b.start(_manager, scene, true)
	await wait_for_signal(fade_b.completed, 2.0)

	# Then: Both used the same overlay instance.
	assert_same(fade_a._overlay, fade_b._overlay)


func test_overlay_color_updates_on_start():
	# Given: A fade transition with a custom color.
	var fade := _create_fade()
	fade.color = Color.RED
	var scene := _create_scene()

	# When: The fade starts.
	fade.start(_manager, scene, false)
	await wait_for_signal(fade.completed, 2.0)

	# Then: The overlay color matches.
	var overlay := _get_overlay()
	assert_eq(overlay.color, Color.RED)


func test_stop_does_not_emit_completed():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()
	watch_signals(fade)

	# When: The fade is started and stopped.
	fade.start(_manager, scene, false)
	await wait_process_frames(2)
	fade.stop()
	await wait_physics_frames(2)

	# Then: The completed signal was not emitted.
	assert_signal_not_emitted(fade, "completed")


func test_reset_does_not_emit_completed():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()
	watch_signals(fade)

	# When: The fade is started and reset.
	fade.start(_manager, scene, false)
	await wait_process_frames(2)
	fade.reset()
	await wait_physics_frames(2)

	# Then: The completed signal was not emitted.
	assert_signal_not_emitted(fade, "completed")


func test_overlay_mouse_filter_is_ignore():
	# Given: A fade transition.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: The fade starts (creating the overlay).
	fade.start(_manager, scene, false)
	await wait_for_signal(fade.completed, 2.0)

	# Then: The overlay does not intercept mouse input.
	var overlay := _get_overlay()
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_fade_uses_proportional_duration():
	# Given: A fade transition with a 0.2s duration and an overlay already at 0.5 alpha.
	var fade := _create_fade()
	fade.duration = 0.2
	var scene := _create_scene()
	_ensure_overlay(0.5)

	# When: An enter fade is started (target 0.0, remaining 0.5).
	var start_time := Time.get_ticks_msec()
	fade.start(_manager, scene, true)
	await wait_for_signal(fade.completed, 2.0)
	var elapsed := Time.get_ticks_msec() - start_time

	# Then: The fade completes in roughly half the configured duration.
	assert_lt(elapsed, 180)


func test_fade_reuse_after_stop():
	# Given: A fade transition that has been started and stopped.
	var fade := _create_fade()
	fade.duration = 0.5
	var scene := _create_scene()

	fade.start(_manager, scene, false)
	await wait_process_frames(2)
	fade.stop()

	# When: The same fade resource is started again.
	fade.duration = 0.01
	fade.start(_manager, scene, true)
	await wait_for_signal(fade.completed, 2.0)

	# Then: The second fade completes successfully.
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_almost_eq(overlay.modulate.a, 0.0, 0.01)


func test_fade_with_zero_duration():
	# Given: A fade transition with zero duration.
	var fade := _create_fade()
	fade.duration = 0.0
	var scene := _create_scene()
	watch_signals(fade)

	# When: An exit fade is started.
	fade.start(_manager, scene, false)
	await wait_for_signal(fade.completed, 2.0)

	# Then: The fade completes and the overlay reaches the target.
	assert_signal_emitted(fade, "completed")
	var overlay := _get_overlay()
	assert_not_null(overlay)
	assert_almost_eq(overlay.modulate.a, 1.0, 0.01)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	_manager = Manager.new()
	_manager.name = &"TestManager"
	add_child_autofree(_manager)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_fade() -> StdScreenTransitionFade:
	var fade := StdScreenTransitionFade.new()
	fade.duration = 0.01
	return fade


func _create_scene() -> Control:
	var scene := Control.new()
	_manager.add_child(scene)
	return scene


func _ensure_overlay(alpha: float) -> ColorRect:
	var overlay := _create_fade()._get_or_create_overlay(_manager)
	overlay.modulate.a = alpha
	return overlay


func _get_overlay() -> ColorRect:
	var key := &"_std_fade_overlay"
	if _manager.has_meta(key):
		return _manager.get_meta(key)
	return null
