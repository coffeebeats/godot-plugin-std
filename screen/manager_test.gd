#gdlint:ignore=max-public-methods
##
## Tests pertaining to the 'StdScreenManager' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Screen := preload("screen.gd")
const Manager := preload("manager.gd")
const Transition := preload("transition.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## MockTransition is a test helper for controlling transition completion.
class MockTransition:
	extends "transition.gd"

	var started := false
	var cancelled := false
	var is_entering_arg: bool

	func _start(_scene: Node, is_entering: bool) -> void:
		started = true
		is_entering_arg = is_entering

	func _cancel() -> void:
		cancelled = true

	## complete triggers transition completion from tests.
	func complete() -> void:
		_done()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_adds_screen_to_stack():
	# Given: A screen manager.
	var manager := _manager

	# When: A screen is pushed.
	var screen := _create_screen()
	manager.push(screen, Control.new())
	await wait_physics_frames(2)

	# Then: The stack has one screen.
	assert_eq(manager.get_depth(), 1)
	assert_true(manager.is_current(screen))


func test_push_emits_lifecycle_signals():
	# Given: A screen manager with signal tracking.
	var manager := _manager
	watch_signals(manager)

	# When: A screen is pushed.
	var screen := _create_screen()
	var scene := Control.new()
	manager.push(screen, scene)
	await wait_physics_frames(2)

	# Then: Lifecycle signals are emitted.
	assert_signal_emitted(manager, "screen_entering")
	assert_signal_emitted(manager, "screen_entered")
	assert_signal_emitted(manager, "screen_pushed")


func test_push_emits_covered_on_previous():
	# Given: A manager with one screen.
	var manager := _manager
	var first := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)

	watch_signals(manager)

	# When: A second screen is pushed.
	var second := _create_screen()
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# Then: The first screen emits covered.
	assert_signal_emitted(manager, "screen_covered")


func test_push_sets_meta_on_scene():
	# Given: A screen manager.
	var manager := _manager

	# When: A screen is pushed with a scene.
	var screen := _create_screen()
	var scene := Control.new()
	manager.push(screen, scene)
	await wait_physics_frames(2)

	# Then: The scene has the screen as meta.
	assert_eq(scene.get_meta(&"std_screen"), screen)


func test_push_with_blocking_transition_emits_entered_after_complete():
	# Given: A screen manager and a blocking enter transition.
	var manager := _manager
	var transition := MockTransition.new()

	var screen := _create_screen()
	screen.enter_transition = transition
	screen.block_on_enter = true

	watch_signals(manager)

	# When: A screen with blocking transition is pushed.
	manager.push(screen, Control.new())
	await wait_physics_frames(2)

	# Then: The transition has started but entered not yet emitted.
	assert_true(transition.started)
	assert_signal_not_emitted(manager, "screen_entered")

	# When: The transition completes.
	transition.complete()
	await wait_physics_frames(2)

	# Then: The entered signal is emitted.
	assert_signal_emitted(manager, "screen_entered")


func test_push_with_nonblocking_transition_emits_entered_immediately():
	# Given: A screen manager and a non-blocking enter transition.
	var manager := _manager
	var transition := MockTransition.new()

	var screen := _create_screen()
	screen.enter_transition = transition

	watch_signals(manager)

	# When: A screen with non-blocking transition is pushed.
	manager.push(screen, Control.new())
	await wait_physics_frames(2)

	# Then: The entered signal is emitted immediately (before transition completes).
	assert_true(transition.started)
	assert_signal_emitted(manager, "screen_entered")


func test_pop_removes_top_screen():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# When: The top screen is popped.
	manager.pop()
	await wait_physics_frames(2)

	# Then: Only the first remains.
	assert_eq(manager.get_depth(), 1)
	assert_true(manager.is_current(first))


func test_pop_emits_lifecycle_signals():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	watch_signals(manager)

	# When: The top screen is popped.
	manager.pop()
	await wait_physics_frames(2)

	# Then: Exit and pop signals are emitted.
	assert_signal_emitted(manager, "screen_exiting")
	assert_signal_emitted(manager, "screen_popped")


func test_pop_emits_uncovered_on_new_top():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	watch_signals(manager)

	# When: The top screen is popped.
	manager.pop()
	await wait_physics_frames(2)

	# Then: The new top emits uncovered.
	assert_signal_emitted(manager, "screen_uncovered")


func test_replace_swaps_top_screen():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# When: The top is replaced.
	var replacement := _create_screen()
	manager.replace(replacement, Control.new())
	await wait_physics_frames(2)

	# Then: The stack depth is unchanged and new screen is on top.
	assert_eq(manager.get_depth(), 2)
	assert_true(manager.is_current(replacement))
	assert_eq(manager.get_at(0), first)


func test_replace_emits_replaced_signal():
	# Given: A manager with one screen.
	var manager := _manager
	var original := _create_screen()
	manager.push(original, Control.new())
	await wait_physics_frames(2)

	watch_signals(manager)

	# When: The top is replaced.
	var replacement := _create_screen()
	manager.replace(replacement, Control.new())
	await wait_physics_frames(2)

	# Then: The replaced signal is emitted.
	assert_signal_emitted(manager, "screen_replaced")


func test_reset_clears_stack_and_pushes_new_base():
	# Given: A manager with three screens.
	var manager := _manager
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# When: The stack is reset with a new screen.
	var new_base := _create_screen()
	manager.reset(new_base, Control.new())
	await wait_physics_frames(2)

	# Then: Only the new base remains.
	assert_eq(manager.get_depth(), 1)
	assert_true(manager.is_current(new_base))


func test_reset_emits_exiting_before_exited():
	# Given: A manager with one screen.
	var manager := _manager
	var original := _create_screen()
	manager.push(original, Control.new())
	await wait_physics_frames(2)

	var signals_order: Array[String] = []
	manager.screen_exiting.connect(func(_s, _sc): signals_order.append("exiting"))
	manager.screen_exited.connect(func(_s, _sc): signals_order.append("exited"))

	# When: The stack is reset.
	manager.reset(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# Then: Exiting was emitted before exited.
	assert_eq(signals_order, ["exiting", "exited"])


func test_pop_to_pops_until_target_is_on_top():
	# Given: A manager with three screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	var third := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)
	manager.push(third, Control.new())
	await wait_physics_frames(2)

	# When: pop_to is called with the first screen.
	manager.pop_to(first)
	await wait_physics_frames(2)

	# Then: Only the first screen remains.
	assert_eq(manager.get_depth(), 1)
	assert_true(manager.is_current(first))


func test_pop_to_depth_pops_to_target_depth():
	# Given: A manager with three screens.
	var manager := _manager
	var first := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# When: pop_to_depth is called with depth 1.
	manager.pop_to_depth(1)
	await wait_physics_frames(2)

	# Then: Only the first screen remains.
	assert_eq(manager.get_depth(), 1)
	assert_true(manager.is_current(first))


func test_cancel_active_stops_blocking_transition():
	# Given: A manager with a screen that has a blocking enter transition.
	var manager := _manager
	var transition := MockTransition.new()

	var first := _create_screen()
	first.enter_transition = transition
	first.block_on_enter = true

	manager.push(first, Control.new())
	await wait_physics_frames(2)

	# Then: The transition is active.
	assert_true(transition.started)
	assert_false(transition.cancelled)

	# When: Another screen is pushed (which cancels active transitions).
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# Then: The first transition was cancelled.
	assert_true(transition.cancelled)


func test_cancel_active_stops_nonblocking_transition():
	# Given: A manager with a screen that has a non-blocking (fire-and-forget)
	# enter transition.
	var manager := _manager
	var transition := MockTransition.new()

	var first := _create_screen()
	first.enter_transition = transition

	manager.push(first, Control.new())
	await wait_physics_frames(2)

	# Then: The transition is tracked even though non-blocking.
	assert_true(transition.started)
	assert_false(transition.cancelled)

	# When: Another screen is pushed (which cancels active transitions).
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# Then: The fire-and-forget transition was cancelled.
	assert_true(transition.cancelled)


func test_push_all_pushes_multiple_screens():
	# Given: A screen manager.
	var manager := _manager

	var screens: Array[Screen] = [
		_create_screen(),
		_create_screen(),
		_create_screen(),
	]
	var instances: Array[Node] = [Control.new(), Control.new(), Control.new()]

	# When: push_all is called with multiple screens.
	manager.push_all(screens, false, instances)
	await wait_physics_frames(4)

	# Then: All screens are on the stack.
	assert_eq(manager.get_depth(), 3)
	assert_true(manager.is_current(screens[2]))
	assert_eq(manager.get_at(0), screens[0])
	assert_eq(manager.get_at(1), screens[1])


func test_push_all_skips_intermediate_transitions():
	# Given: A screen manager with screens that have blocking transitions.
	var manager := _manager

	var transitions: Array[MockTransition] = []
	var screens: Array[Screen] = []
	var instances: Array[Node] = []

	for i in range(3):
		var transition := MockTransition.new()
		transitions.append(transition)

		var screen := _create_screen()
		screen.enter_transition = transition
		screen.block_on_enter = true
		screens.append(screen)
		instances.append(Control.new())

	# When: push_all is called without animate_intermediate.
	manager.push_all(screens, false, instances)
	await wait_physics_frames(2)

	# Then: Only the last transition was started.
	assert_false(transitions[0].started)
	assert_false(transitions[1].started)
	assert_true(transitions[2].started)


func test_push_all_with_animate_intermediate_plays_all():
	# Given: A screen manager with screens that have non-blocking transitions.
	var manager := _manager

	var transitions: Array[MockTransition] = []
	var screens: Array[Screen] = []
	var instances: Array[Node] = []

	for i in range(3):
		var transition := MockTransition.new()
		transitions.append(transition)

		var screen := _create_screen()
		screen.enter_transition = transition
		screens.append(screen)
		instances.append(Control.new())

	# When: push_all is called with animate_intermediate=true.
	manager.push_all(screens, true, instances)
	await wait_physics_frames(4)

	# Then: All transitions were started.
	assert_true(transitions[0].started)
	assert_true(transitions[1].started)
	assert_true(transitions[2].started)


func test_pop_to_skips_intermediate_transitions():
	# Given: A manager with three screens that have blocking exit transitions.
	var manager := _manager

	var transitions: Array[MockTransition] = []
	var screens: Array[Screen] = []

	for i in range(3):
		var transition := MockTransition.new()
		transitions.append(transition)

		var screen := _create_screen()
		screen.exit_transition = transition
		screen.block_on_exit = true
		screens.append(screen)

	for screen in screens:
		manager.push(screen, Control.new())
		await wait_physics_frames(2)

	# When: pop_to is called to the first screen without animate_intermediate.
	manager.pop_to(screens[0], false)
	await wait_physics_frames(2)

	# Then: Only the last exit transition was started (the one closest to target).
	assert_false(transitions[0].started)
	assert_true(transitions[1].started)
	assert_false(transitions[2].started)


func test_pop_to_with_animate_intermediate_plays_all():
	# Given: A manager with three screens that have non-blocking exit transitions.
	var manager := _manager

	var transitions: Array[MockTransition] = []
	var screens: Array[Screen] = []

	for i in range(3):
		var transition := MockTransition.new()
		transitions.append(transition)

		var screen := _create_screen()
		screen.exit_transition = transition
		screens.append(screen)

	for screen in screens:
		manager.push(screen, Control.new())
		await wait_physics_frames(2)

	# When: pop_to is called with animate_intermediate=true.
	manager.pop_to(screens[0], true)
	await wait_physics_frames(4)

	# Then: All exit transitions were started (except the first which stays).
	assert_false(transitions[0].started)
	assert_true(transitions[1].started)
	assert_true(transitions[2].started)


func test_screen_signals_emitted_on_push():
	# Given: A screen manager and a screen with signal tracking.
	var manager := _manager
	var screen := _create_screen()
	var scene := Control.new()

	# NOTE: Use a dictionary since GDScript lambdas capture by value.
	var received := {"entering": false, "entered": false}
	screen.entering.connect(func(_s): received["entering"] = true)
	screen.entered.connect(func(_s): received["entered"] = true)

	# When: The screen is pushed.
	manager.push(screen, scene)
	await wait_physics_frames(2)

	# Then: The screen's lifecycle signals were emitted.
	assert_true(received["entering"])
	assert_true(received["entered"])


func test_screen_signals_emitted_on_pop():
	# Given: A manager with two screens and signal tracking on the top.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()

	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# NOTE: Use a dictionary since GDScript lambdas capture by value.
	var received := {"exiting": false, "exited": false}
	second.exiting.connect(func(_s): received["exiting"] = true)
	second.exited.connect(func(_s): received["exited"] = true)

	# When: The top screen is popped.
	manager.pop()
	await wait_physics_frames(2)

	# Then: The screen's lifecycle signals were emitted.
	assert_true(received["exiting"])
	assert_true(received["exited"])


func test_get_current_returns_topmost_screen():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# Then: get_current returns the second screen.
	assert_eq(manager.get_current(), second)


func test_get_scene_returns_topmost_scene():
	# Given: A manager with a screen.
	var manager := _manager
	var screen := _create_screen()
	var scene := Control.new()
	manager.push(screen, scene)
	await wait_physics_frames(2)

	# Then: get_scene returns the scene instance.
	assert_eq(manager.get_scene(), scene)


func test_get_at_returns_screen_at_index():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# Then: get_at returns correct screens.
	assert_eq(manager.get_at(0), first)
	assert_eq(manager.get_at(1), second)


func test_get_index_of_returns_correct_index():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# Then: get_index_of returns correct indices.
	assert_eq(manager.get_index_of(first), 0)
	assert_eq(manager.get_index_of(second), 1)


func test_get_index_of_returns_negative_one_for_missing():
	# Given: A manager with one screen.
	var manager := _manager
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# Then: A screen not in the stack returns -1.
	var other := _create_screen()
	assert_eq(manager.get_index_of(other), -1)


func test_is_current_returns_false_for_non_top():
	# Given: A manager with two screens.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	# Then: is_current is false for the first screen.
	assert_false(manager.is_current(first))
	assert_true(manager.is_current(second))


func test_pause_when_covered_disables_process_mode():
	# Given: A manager with a screen that pauses when covered.
	var manager := _manager
	var first := _create_screen()
	first.pause_when_covered = true
	var first_scene := Control.new()
	manager.push(first, first_scene)
	await wait_physics_frames(2)

	# When: A second screen is pushed.
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# Then: The first scene's process mode is disabled.
	assert_eq(
		first_scene.process_mode,
		Node.PROCESS_MODE_DISABLED,
	)


func test_pause_when_covered_false_keeps_process_mode():
	# Given: A screen that does not pause when covered.
	var manager := _manager
	var first := _create_screen()
	first.pause_when_covered = false
	var first_scene := Control.new()
	manager.push(first, first_scene)
	await wait_physics_frames(2)

	# When: A second screen is pushed.
	manager.push(_create_screen(), Control.new())
	await wait_physics_frames(2)

	# Then: The first scene's process mode is unchanged.
	assert_ne(
		first_scene.process_mode,
		Node.PROCESS_MODE_DISABLED,
	)


func test_get_current_returns_null_when_empty():
	# Given: A manager with no screens.
	var manager := _manager

	# Then: get_current returns null.
	assert_null(manager.get_current())


func test_get_scene_returns_null_when_empty():
	# Given: A manager with no screens.
	var manager := _manager

	# Then: get_scene returns null.
	assert_null(manager.get_scene())


func test_get_depth_returns_zero_when_empty():
	# Given: A manager with no screens.
	var manager := _manager

	# Then: get_depth returns 0.
	assert_eq(manager.get_depth(), 0)


func test_cancelled_nonblocking_exit_frees_scene():
	# Given: A manager with two screens; the second has a
	# non-blocking exit transition.
	var manager := _manager
	var first := _create_screen()
	manager.push(first, Control.new())
	await wait_physics_frames(2)

	var exit_transition := MockTransition.new()
	var second := _create_screen()
	second.exit_transition = exit_transition
	var second_scene := Control.new()
	manager.push(second, second_scene)
	await wait_physics_frames(2)

	# When: The second screen is popped (exit starts).
	manager.pop()
	await wait_physics_frames(2)

	# Then: The exit transition is in flight.
	assert_true(exit_transition.started)

	# When: A third screen is pushed (cancels active transitions).
	var third := _create_screen()
	manager.push(third, Control.new())
	await wait_physics_frames(4)

	# Then: The second scene is freed.
	assert_false(is_instance_valid(second_scene))


func test_duplicate_screen_push_is_dropped():
	# Given: A manager with one screen.
	var manager := _manager
	var screen := _create_screen()
	manager.push(screen, Control.new())
	await wait_physics_frames(2)

	# When: The same screen is pushed again.
	var duplicate := Control.new()
	manager.push(screen, duplicate)
	await wait_physics_frames(2)

	# Then: The stack depth remains 1 and the screen is current.
	assert_eq(manager.get_depth(), 1)
	assert_true(manager.is_current(screen))

	# Cleanup: Free the orphaned instance that was rejected.
	duplicate.free()


func test_queued_push_from_signal_handler():
	# Given: A manager with a signal handler that pushes a second
	# screen when screen_pushed fires.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()

	manager.screen_pushed.connect(
		func(_s): manager.push(second, Control.new()),
		CONNECT_ONE_SHOT,
	)

	# When: The first screen is pushed.
	manager.push(first, Control.new())
	await wait_physics_frames(4)

	# Then: Both screens are on the stack in order.
	assert_eq(manager.get_depth(), 2)
	assert_eq(manager.get_at(0), first)
	assert_eq(manager.get_at(1), second)


func test_queued_pop_from_signal_handler():
	# Given: A manager with two screens, and a signal handler
	# that pops when a third screen is pushed.
	var manager := _manager
	var first := _create_screen()
	var second := _create_screen()
	var third := _create_screen()

	manager.push(first, Control.new())
	await wait_physics_frames(2)
	manager.push(second, Control.new())
	await wait_physics_frames(2)

	manager.screen_pushed.connect(
		func(_s): manager.pop(),
		CONNECT_ONE_SHOT,
	)

	# When: A third screen is pushed.
	manager.push(third, Control.new())
	await wait_physics_frames(4)

	# Then: The third was pushed then popped; stack is
	# [first, second].
	assert_eq(manager.get_depth(), 2)
	assert_eq(manager.get_at(0), first)
	assert_eq(manager.get_at(1), second)


func test_replace_emits_lifecycle_in_correct_order():
	# Given: A manager with one screen.
	var manager := _manager
	var original := _create_screen()
	manager.push(original, Control.new())
	await wait_physics_frames(2)

	var order: Array[String] = []
	manager.screen_exiting.connect(func(_s, _sc): order.append("exiting"))
	manager.screen_exited.connect(func(_s, _sc): order.append("exited"))
	manager.screen_entering.connect(func(_s, _sc): order.append("entering"))
	manager.screen_entered.connect(func(_s, _sc): order.append("entered"))
	manager.screen_replaced.connect(func(_o, _n): order.append("replaced"))

	# When: The top is replaced.
	var replacement := _create_screen()
	manager.replace(replacement, Control.new())
	await wait_physics_frames(4)

	# Then: Signals fire in the correct order.
	assert_eq(
		order,
		[
			"exiting",
			"exited",
			"entering",
			"entered",
			"replaced",
		],
	)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_physics_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_screen() -> Screen:
	return Screen.new()
