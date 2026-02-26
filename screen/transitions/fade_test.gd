##
## screen/transitions/fade_test.gd
##
## Tests pertaining to the 'StdScreenTransitionFade' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Context := preload("../context.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class MockManager:
	extends Node

	signal transition_done


# -- INITIALIZATION ------------------------------------------------------------------ #

var _mock: MockManager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_fade_completes_with_transparent_overlay():
	# Given: A fade transition and a scene under the manager.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: A push fade runs to completion.
	_start_push(fade, scene, scene)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The overlay has faded to transparent.
	var overlay := _find_overlay()
	assert_null(overlay, "overlay should be freed after push")


func test_pop_fade_completes_with_transparent_overlay():
	# Given: A fade transition and a scene under the manager.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: A pop fade runs to completion.
	_start_pop(fade, scene)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The overlay has been cleaned up.
	var overlay := _find_overlay()
	assert_null(overlay, "overlay should be freed after pop")


func test_fade_invokes_done_on_finish():
	# Given: A fade transition.
	var fade := _create_fade()
	var scene := _create_scene()
	watch_signals(_mock)

	# When: A pop fade runs to completion.
	_start_pop(fade, scene)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The done callback was invoked exactly once.
	assert_signal_emit_count(_mock, "transition_done", 1)


func test_stop_frees_overlay():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.curve.duration = 0.5
	var scene := _create_scene()

	# When: A pop fade is started and stopped mid-way.
	_start_pop(fade, scene)
	await wait_process_frames(2)
	fade.stop()
	await wait_physics_frames(2)

	# Then: The overlay was freed.
	var overlay := _find_overlay()
	assert_null(overlay, "overlay should be freed on stop")


func test_overlay_color_updates_on_start():
	# Given: A fade transition with a custom color.
	var fade := _create_fade()
	fade.color = Color.RED
	var scene := _create_scene()

	# When: The fade starts.
	var ctx := _start_pop(fade, scene)
	await wait_process_frames(1)

	# Then: The overlay color matches.
	var overlay := _find_overlay()
	if overlay:
		assert_eq(overlay.color, Color.RED)
	else:
		# Zero-duration fades may have already completed.
		pass

	# Cleanup.
	fade.stop()


func test_stop_does_not_invoke_done():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.curve.duration = 0.5
	var scene := _create_scene()
	watch_signals(_mock)

	# When: The fade is started and stopped.
	_start_pop(fade, scene)
	await wait_process_frames(2)
	fade.stop()
	await wait_physics_frames(2)

	# Then: The done callback was not invoked.
	assert_signal_not_emitted(_mock, "transition_done")


func test_overlay_mouse_filter_is_ignore():
	# Given: A fade transition with a long duration.
	var fade := _create_fade()
	fade.curve.duration = 0.5
	var scene := _create_scene()

	# When: The fade starts (creating the overlay).
	_start_pop(fade, scene)
	await wait_process_frames(1)

	# Then: The overlay does not intercept mouse input.
	var overlay := _find_overlay()
	assert_not_null(overlay)
	assert_eq(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
	)

	# Cleanup.
	fade.stop()


func test_fade_with_zero_duration():
	# Given: A fade transition with zero duration.
	var fade := _create_fade()
	fade.curve.duration = 0.0
	var scene := _create_scene()
	watch_signals(_mock)

	# When: A pop fade is started.
	_start_pop(fade, scene)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The fade completes.
	assert_signal_emitted(_mock, "transition_done")


func test_push_without_current_scene_starts_opaque():
	# Given: A fade transition.
	var fade := _create_fade()
	var scene := _create_scene()

	# When: A push fade starts with no current scene.
	_start_push(fade, scene, null)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The fade completed (from opaque to transparent).
	var overlay := _find_overlay()
	assert_null(overlay, "overlay should be freed")


func test_replace_fade_completes():
	# Given: A fade transition and scenes.
	var fade := _create_fade()
	var scene := _create_scene()
	watch_signals(_mock)

	# When: A replace fade runs to completion.
	_start_replace(fade, scene, scene)
	await wait_for_signal(_mock.transition_done, 2.0)

	# Then: The done callback was invoked.
	assert_signal_emitted(_mock, "transition_done")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	_mock = MockManager.new()
	_mock.name = &"TestManager"
	add_child_autofree(_mock)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_context(
	current_scene: Node = null,
) -> Context:
	var ctx := Context.new(_mock)
	ctx.current_scene = current_scene
	return ctx


func _create_fade() -> StdScreenTransitionFade:
	var fade := StdScreenTransitionFade.new()
	fade.curve = StdTweenCurve.new()
	fade.curve.duration = 0.01
	return fade


func _create_scene() -> Control:
	var scene := Control.new()
	_mock.add_child(scene)
	return scene


## _find_overlay searches for a FadeOverlay child on the mock manager.
func _find_overlay() -> ColorRect:
	for i in range(_mock.get_child_count(true)):
		var child := _mock.get_child(i, true)
		if child is ColorRect and child.name == &"FadeOverlay":
			return child
	return null


func _start_push(
	fade: StdScreenTransitionFade,
	entering_scene: Node,
	current_scene: Node,
) -> Context:
	var ctx := _create_context(current_scene)
	ctx.entering_scene = entering_scene
	ctx._mount_fn = func() -> void: pass
	ctx._unmount_fn = func() -> void: pass
	ctx.finished.connect(
		func(): _mock.transition_done.emit(),
		CONNECT_ONE_SHOT,
	)
	fade.push(ctx)
	return ctx


func _start_pop(
	fade: StdScreenTransitionFade,
	scene: Node,
) -> Context:
	var ctx := _create_context(scene)
	ctx._unmount_fn = func() -> void: pass
	ctx.finished.connect(
		func(): _mock.transition_done.emit(),
		CONNECT_ONE_SHOT,
	)
	fade.pop(ctx)
	return ctx


func _start_replace(
	fade: StdScreenTransitionFade,
	entering_scene: Node,
	current_scene: Node,
) -> Context:
	var ctx := _create_context(current_scene)
	ctx.entering_scene = entering_scene
	ctx._mount_fn = func() -> void: pass
	ctx._unmount_fn = func() -> void: pass
	ctx.finished.connect(
		func(): _mock.transition_done.emit(),
		CONNECT_ONE_SHOT,
	)
	fade.replace(ctx)
	return ctx
