##
## std/transition/fade_test.gd
##
## Tests pertaining to the 'StdTransitionFade' class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## _CountingContext counts its unmounts, since nothing else shows that one ran on a node
## without `visible`.
class _CountingContext:
	extends StdTransitionContext

	var unmounts: int = 0

	func _unmount() -> void:
		unmounts += 1


# -- TEST METHODS -------------------------------------------------------------------- #


func test_fade_with_one_resource_runs_screen_push_and_plain_control():
	# Given: One fade resource.
	var fade := _create_fade(0.1)

	# Given: A screen stack.
	add_child_autofree(StdInputCursor.new())
	var manager := StdTestScreenManager.new()
	add_child_autofree(manager)
	await wait_process_frames(1)

	# Given: A screen with a scene rooted in a `CanvasItem`.
	var screen := StdScreen.new()
	screen.transition = fade
	var scene := Control.new()

	# When: The screen is pushed.
	manager.push(screen, scene)
	await wait_until(scene.is_inside_tree, 2.0)

	# Then: The scene starts faded out.
	assert_lt(scene.modulate.a, 1.0)

	# When: The push finishes.
	await wait_for_signal(screen.entered, 2.0)

	# Then: The scene is fully shown.
	assert_eq(scene.modulate.a, 1.0)

	# Given: A plain hidden control in the same tree.
	var control := Control.new()
	control.hide()
	add_child_autofree(control)
	var ctx := StdTransitionContext.new(control)
	ctx.entering = control

	# When: The same resource runs on it.
	fade.duplicate().enter(ctx)

	# Then: The control shows, faded out.
	assert_true(control.visible)
	assert_eq(control.modulate.a, 0.0)

	# When: The transition finishes.
	await wait_for_signal(ctx.finished, 2.0)

	# Then: The control is fully shown.
	assert_eq(control.modulate.a, 1.0)


func test_fade_with_screen_pop_fades_scene_before_unmounting():
	# Given: A screen stack.
	var manager := await _create_manager()

	# Given: A screen fading through one resource, already pushed.
	var screen := StdScreen.new()
	screen.transition = _create_fade(0.1)
	var scene := Control.new()
	await manager.push_and_wait(screen, scene)

	# When: The screen is popped.
	manager.pop()
	await wait_until(func() -> bool: return scene.modulate.a < 1.0, 2.0)

	# Then: The scene is fading while still mounted.
	assert_true(scene.is_inside_tree())
	assert_lt(scene.modulate.a, 1.0)

	# When: The pop finishes.
	await wait_for_signal(screen.popped, 2.0)

	# Then: The screen has left the stack.
	assert_false(manager.is_current(screen))


func test_fade_with_screen_replace_fades_old_then_new_scene():
	# Given: A screen stack.
	var manager := await _create_manager()

	# Given: A screen already pushed.
	var scene_old := Control.new()
	await manager.push_and_wait(StdScreen.new(), scene_old)

	# Given: A screen to replace it, fading through one resource.
	var screen := StdScreen.new()
	screen.transition = _create_fade(0.1)
	var scene_new := Control.new()

	# When: The replace starts.
	manager.replace(screen, scene_new)
	await wait_until(func() -> bool: return scene_old.modulate.a < 1.0, 2.0)

	# Then: The old scene is fading while still mounted.
	assert_true(scene_old.is_inside_tree())

	# Then: The new scene isn't mounted yet.
	assert_false(scene_new.is_inside_tree())

	# When: The replace finishes.
	await wait_for_signal(screen.entered, 2.0)

	# Then: The new scene is fully shown.
	assert_eq(scene_new.modulate.a, 1.0)


func test_fade_with_cached_screen_pop_leaves_scene_at_full_alpha():
	# Given: A screen stack.
	var manager := await _create_manager()

	# Given: A cached screen fading through one resource, already pushed.
	var screen := StdScreen.new()
	screen.cache_instance = true
	screen.transition = _create_fade()
	var scene := Control.new()
	await manager.push_and_wait(screen, scene)

	# When: The screen is popped.
	manager.pop()
	await wait_for_signal(screen.popped, 2.0)

	# Then: The cached scene would show at full alpha without a transition.
	assert_eq(scene.modulate.a, 1.0)


func test_fade_enter_with_authored_alpha_returns_to_it():
	# Given: A control authored partly transparent.
	var control := _create_control()
	control.modulate.a = 0.5
	var ctx := _create_context(control, null)

	# When: It fades in.
	_create_fade().enter(ctx)
	await wait_for_signal(ctx.finished, 2.0)

	# Then: It ends at its authored alpha.
	assert_almost_eq(control.modulate.a, 0.5, 0.001)


func test_fade_exit_hides_control_and_restores_alpha():
	# Given: A shown control.
	var control := _create_control()
	var ctx := _create_context(null, control)

	# When: It fades out.
	_create_fade().exit(ctx)

	# Then: It stays shown during the fade.
	assert_true(control.visible)

	# When: The fade finishes.
	await wait_for_signal(ctx.finished, 2.0)

	# Then: It's hidden.
	assert_false(control.visible)

	# Then: It would show at full alpha if shown again without a transition.
	assert_eq(control.modulate.a, 1.0)


func test_fade_swap_replaces_exiting_with_entering():
	# Given: A shown control and a hidden one.
	var exiting := _create_control()
	var entering := _create_control()
	entering.hide()
	var ctx := _create_context(entering, exiting)

	# When: The fade swaps them.
	_create_fade().swap(ctx)

	# Then: Neither changes until the first fade finishes.
	assert_true(exiting.visible)
	assert_false(entering.visible)

	# When: The fade finishes.
	await wait_for_signal(ctx.finished, 2.0)

	# Then: Only the entering control shows.
	assert_false(exiting.visible)
	assert_true(entering.visible)

	# Then: Both controls are at full alpha.
	assert_eq(exiting.modulate.a, 1.0)
	assert_eq(entering.modulate.a, 1.0)


func test_fade_stop_during_enter_restores_alpha_without_finishing():
	# Given: A control fading in.
	var control := _create_control()
	var ctx := _create_context(control, null)
	watch_signals(ctx)
	var fade := _create_fade(0.5)
	fade.enter(ctx)
	assert_eq(control.modulate.a, 0.0)

	# When: The transition is stopped.
	fade.stop()
	await wait_seconds(0.05)

	# Then: The control is left at full alpha.
	assert_eq(control.modulate.a, 1.0)

	# Then: Completion is never reported.
	assert_signal_not_emitted(ctx, "finished")


func test_fade_stop_after_control_freed_does_nothing():
	# Given: A control fading in.
	var control := _create_control()
	var fade := _create_fade(0.5)
	fade.enter(_create_context(control, null))

	# When: The control is freed and the transition stopped.
	control.get_parent().remove_child(control)
	control.free()
	fade.stop()

	# Then: Nothing touched the freed control.
	assert_engine_error_count(0)


func test_fade_enter_with_node_root_finishes_at_once():
	# Given: An entering node that isn't a `CanvasItem`.
	var node := Node3D.new()
	add_child_autofree(node)
	var ctx := StdTransitionContext.new(node)
	ctx.entering = node
	watch_signals(ctx)

	# When: A fade enters it.
	_create_fade().enter(ctx)

	# Then: The transition finished without a frame passing.
	assert_signal_emit_count(ctx, "finished", 1)


func test_fade_exit_with_node_root_unmounts_at_once():
	# Given: An exiting node that isn't a `CanvasItem`.
	var node := Node3D.new()
	add_child_autofree(node)
	var ctx := _CountingContext.new(node)
	ctx.exiting = node
	watch_signals(ctx)

	# When: A fade exits it.
	_create_fade().exit(ctx)

	# Then: The node's exit ran.
	assert_eq(ctx.unmounts, 1)

	# Then: The transition finished without a frame passing.
	assert_signal_emit_count(ctx, "finished", 1)


func test_fade_with_curve_overrides_uses_them_over_curve():
	# Given: A fade configured only through its overrides.
	var fade := StdTransitionFade.new()
	fade.curve_enter = StdTweenCurve.new()
	fade.curve_enter.duration = 0.01
	fade.curve_exit = StdTweenCurve.new()
	fade.curve_exit.duration = 0.01

	var entering := _create_control()
	entering.hide()
	var exiting := _create_control()
	var ctx := _create_context(entering, exiting)

	# When: It swaps two controls.
	fade.swap(ctx)
	await wait_for_signal(ctx.finished, 2.0)

	# Then: Both phases ran.
	assert_true(entering.visible)
	assert_false(exiting.visible)


func test_fade_with_block_input_covers_exiting_until_finished():
	# Given: A control fading out.
	var control := _create_control()
	var ctx := _create_context(null, control)
	_create_fade(0.01).exit(ctx)

	# Then: It's covered during the fade.
	assert_eq(control.get_child_count(true), 1)

	# When: The fade finishes.
	await wait_for_signal(ctx.finished, 2.0)

	# Then: Nothing covers it.
	await wait_process_frames(1)
	assert_eq(control.get_child_count(true), 0)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_context(entering: Node, exiting: Node) -> StdTransitionContext:
	var ctx := StdTransitionContext.new(entering if entering else exiting)
	ctx.entering = entering
	ctx.exiting = exiting
	return ctx


func _create_control() -> Control:
	var control := Control.new()
	add_child_autofree(control)
	return control


func _create_manager() -> StdTestScreenManager:
	add_child_autofree(StdInputCursor.new())

	var manager := StdTestScreenManager.new()
	add_child_autofree(manager)

	await wait_process_frames(1)

	return manager


func _create_fade(duration: float = 0.01) -> StdTransitionFade:
	var fade := StdTransitionFade.new()
	fade.curve = StdTweenCurve.new()
	fade.curve.duration = duration
	return fade
