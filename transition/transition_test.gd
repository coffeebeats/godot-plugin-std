##
## std/transition/transition_test.gd
##
## Tests pertaining to the 'StdTransition' class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## MockTransition records which lifecycle methods were called and exposes helpers for
## driving the transition from test code.
class MockTransition:
	extends StdTransition

	var enter_started := false
	var exit_started := false
	var swap_started := false
	var stopped := false

	var _ctx: StdTransitionContext

	func _enter(context: StdTransitionContext) -> void:
		_ctx = context
		enter_started = true

	func _exit(context: StdTransitionContext) -> void:
		_ctx = context
		exit_started = true

	func _swap(context: StdTransitionContext) -> void:
		_ctx = context
		swap_started = true

	func _stop() -> void:
		stopped = true

	## complete triggers transition completion from tests.
	func complete() -> void:
		_ctx.done()

	## do_mount calls mount on the context.
	func do_mount() -> void:
		_ctx.mount()

	## do_swap calls swap on the context (for testing lifecycle).
	func do_swap() -> void:
		_ctx.swap()

	## do_unmount calls unmount on the context.
	func do_unmount() -> void:
		_ctx.unmount()


# -- TEST METHODS -------------------------------------------------------------------- #


func test_enter_by_default_mounts_and_finishes():
	# Given: A hidden control entering through the base transition.
	var control := _create_control()
	control.hide()
	var ctx := StdTransitionContext.new(control)
	ctx.entering = control
	watch_signals(ctx)

	# When: The transition enters.
	StdTransition.new().enter(ctx)

	# Then: The control shows.
	assert_true(control.visible)

	# Then: The transition finished.
	assert_signal_emit_count(ctx, "finished", 1)


func test_exit_by_default_unmounts_and_finishes():
	# Given: A shown control exiting through the base transition.
	var control := _create_control()
	var ctx := StdTransitionContext.new(control)
	ctx.exiting = control
	watch_signals(ctx)

	# When: The transition exits.
	StdTransition.new().exit(ctx)

	# Then: The control is hidden.
	assert_false(control.visible)

	# Then: The transition finished.
	assert_signal_emit_count(ctx, "finished", 1)


func test_swap_by_default_swaps_and_finishes():
	# Given: A shown control exiting and a hidden one entering.
	var exiting := _create_control()
	var entering := _create_control()
	entering.hide()
	var ctx := StdTransitionContext.new(entering)
	ctx.entering = entering
	ctx.exiting = exiting
	watch_signals(ctx)

	# When: The transition swaps them.
	StdTransition.new().swap(ctx)

	# Then: Only the entering control shows.
	assert_false(exiting.visible)
	assert_true(entering.visible)

	# Then: The transition finished.
	assert_signal_emit_count(ctx, "finished", 1)


func test_stop_while_running_ends_context_without_finishing():
	# Given: A running transition holding a blocker over its control.
	var control := _create_control()
	var ctx := StdTransitionContext.new(control)
	ctx.entering = control
	watch_signals(ctx)
	var tx := MockTransition.new()
	tx.enter(ctx)
	assert_eq(control.get_child_count(true), 1)

	# When: The transition is stopped.
	tx.stop()

	# When: The transition then completes anyway.
	tx.complete()

	# Then: The transition's own stop ran.
	assert_true(tx.stopped)

	# Then: The blocker is gone.
	await wait_process_frames(1)
	assert_eq(control.get_child_count(true), 0)

	# Then: Completion is never reported.
	assert_signal_not_emitted(ctx, "finished")


func test_stop_after_finishing_does_not_release_again():
	# Given: A transition which already finished.
	var control := _create_control()
	var ctx := StdTransitionContext.new(control)
	ctx.entering = control
	watch_signals(ctx)
	var tx := StdTransition.new()
	tx.enter(ctx)

	# When: It's stopped.
	tx.stop()

	# Then: Completion was reported once.
	assert_signal_emit_count(ctx, "finished", 1)


func test_stop_before_running_does_nothing():
	# Given: A transition which never ran.
	var tx := MockTransition.new()

	# When: It's stopped.
	tx.stop()

	# Then: Only its own stop ran.
	assert_true(tx.stopped)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_control() -> Control:
	var control := Control.new()
	add_child_autofree(control)
	return control
