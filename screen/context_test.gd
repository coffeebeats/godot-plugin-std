##
## std/screen/context_test.gd
##
## Tests pertaining to the 'StdScreenTransitionContext' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TransitionTests := preload("../transition/transition_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: StdTestScreenManager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_block_input_during_push_covers_viewport_not_scene():
	# Given: A screen with a transition that blocks input and stays open.
	var screen := StdScreen.new()
	screen.transition = MockTransition.new()
	var scene := Control.new()

	# When: The screen is pushed.
	_manager.push(screen, scene)
	await wait_until(func() -> bool: return _manager._active_transition != null, 2.0)

	# When: The transition mounts the scene.
	_manager._active_transition.do_mount()

	# Then: The manager's own blocker is armed.
	assert_true(_manager._input_blocker.is_inside_tree())

	# Then: Nothing was added to the scene.
	assert_eq(scene.get_child_count(true), 0)

	# When: The transition completes.
	_manager._active_transition.complete()

	# Then: The manager's blocker is released.
	assert_false(_manager._input_blocker.is_inside_tree())


func test_create_tween_under_paused_tree_waits_until_unpaused():
	# Given: A tween from a screen context.
	var ctx := StdScreenTransitionContext.new(_manager)
	var did_run := [false]
	var tween := ctx.create_tween()
	tween.tween_interval(0.01)
	tween.tween_callback(func() -> void: did_run[0] = true)

	# When: The tree stays paused for longer than the tween's duration.
	get_tree().paused = true
	await get_tree().create_timer(0.05, true).timeout

	# Then: The tween hasn't run.
	assert_false(did_run[0])

	# When: The tree resumes.
	get_tree().paused = false
	await get_tree().create_timer(0.05, true).timeout

	# Then: The tween has run.
	assert_true(did_run[0])


func test_mount_with_failed_load_finishes_without_unmounting():
	# Given: A screen context whose scene failed to load.
	var ctx := StdScreenTransitionContext.new(_manager)
	var unmounts := [0]
	ctx._mount_fn = func(_scene: Node) -> void: pass
	ctx._resolver = func() -> Node: return null
	ctx._unmount_fn = func() -> void: unmounts[0] += 1
	watch_signals(ctx)

	# When: A fade tries to bring it in.
	var fade := StdTransitionFade.new()
	fade.curve = StdTweenCurve.new()
	fade.enter(ctx)

	# Then: The transition finished once.
	assert_signal_emit_count(ctx, "finished", 1)

	# When: The context is then told to unmount.
	ctx.unmount()

	# Then: The existing scene is preserved.
	assert_eq(unmounts[0], 0)


func test_mount_overlay_adds_internal_child_of_manager():
	# Given: A screen context.
	var ctx := StdScreenTransitionContext.new(_manager)
	var count := _manager.get_child_count()
	var overlay: Control = autofree(Control.new())

	# When: An overlay is mounted.
	ctx.mount_overlay(overlay)

	# Then: It's under the manager but not among its listed children.
	assert_eq(overlay.get_parent(), _manager)
	assert_eq(_manager.get_child_count(), count)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	get_tree().paused = false


func before_each():
	add_child_autofree(StdInputCursor.new())

	_manager = StdTestScreenManager.new()
	add_child_autofree(_manager)
