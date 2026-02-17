# gdlint:ignore=max-public-methods,max-file-lines

##
## screen/manager/manager_test.gd
##
## Tests pertaining to 'StdScreenManager'.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Screen := preload("../screen.gd")
const Manager := preload("manager.gd")
const Overlay := preload("../overlay.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class MockTransition:
	extends "../transition.gd"

	var started := false
	var stopped := false
	var was_reset := false
	var is_entering_arg: bool

	var _ctx: StdScreenTransitionContext

	func _start(
		context: StdScreenTransitionContext,
		_scene: Node,
		is_entering: bool,
	) -> void:
		_ctx = context
		started = true
		is_entering_arg = is_entering

	func _stop() -> void:
		stopped = true

	func _reset() -> void:
		_stop()
		was_reset = true

	## complete triggers transition completion from tests.
	func complete() -> void:
		_ctx.done()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_adds_screen_to_stack():
	# When: A screen is pushed.
	var screen := _create_screen()
	await _do_push(screen)

	# Then: The stack has one screen.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))


func test_push_with_blocking_transition_emits_entered_after_complete():
	# Given: A blocking enter transition.
	var transition := MockTransition.new()
	var screen := _create_screen(transition)
	screen.block_on_enter = true
	watch_signals(_manager)

	# When: A screen with blocking transition is pushed.
	await _do_push(screen)

	# Then: The transition has started but entered not yet emitted.
	var active := _get_active_transition()
	assert_true(active.started)
	assert_signal_not_emitted(_manager, "screen_entered")

	# When: The transition completes.
	active.complete()
	await wait_idle_frames(1)

	# Then: The entered signal is emitted.
	assert_signal_emitted(_manager, "screen_entered")


func test_push_with_nonblocking_transition_emits_entered_immediately():
	# Given: A non-blocking enter transition.
	var screen := _create_screen(MockTransition.new())
	watch_signals(_manager)

	# When: A screen with non-blocking transition is pushed.
	await _do_push(screen)

	# Then: The entered signal is emitted immediately.
	var active := _get_active_transition()
	assert_true(active.started)
	assert_signal_emitted(_manager, "screen_entered")


func test_pop_removes_top_screen():
	# Given: A manager with two screens.
	var first := _create_screen()
	await _do_push(first)
	await _do_push()

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Only the first remains.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(first))


func test_replace_swaps_top_screen():
	# Given: A manager with two screens.
	var first := _create_screen()
	await _do_push(first)
	await _do_push()

	# When: The top is replaced.
	var replacement := _create_screen()
	_manager.replace(replacement, Control.new())
	await wait_idle_frames(1)

	# Then: The stack depth is unchanged and new screen is on top.
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(replacement))
	assert_eq(_manager.get_at(0), first)


func test_reset_clears_stack_and_pushes_new_base():
	# Given: A manager with three screens.
	await _do_push()
	await _do_push()
	await _do_push()

	# When: The stack is reset with a new screen.
	var new_base := _create_screen()
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)

	# Then: Only the new base remains.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(new_base))


func test_pop_to_and_pop_to_depth():
	# Given: A manager with three screens.
	var first := _create_screen()
	await _do_push(first)
	await _do_push()
	await _do_push()

	# When: pop_to is called with the first screen.
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: Only the first screen remains.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(first))

	# Given: Two more screens are pushed.
	await _do_push()
	await _do_push()

	# When: pop_to_depth is called with depth 1.
	_manager.pop_to_depth(1)
	await wait_idle_frames(1)

	# Then: Only the first screen remains.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(first))


func test_interrupt_resets_blocking_and_nonblocking_transitions():
	# Given: A screen with a blocking enter transition.
	var first := _create_screen(MockTransition.new())
	first.block_on_enter = true
	await _do_push(first)
	var active_blocking := _get_active_transition()
	assert_true(active_blocking.started)

	# When: Another screen is pushed (which resets active transitions).
	await _do_push()

	# Then: The blocking transition was reset.
	assert_true(active_blocking.was_reset)

	# Given: A screen with a non-blocking enter transition.
	var second := _create_screen(MockTransition.new())
	await _do_push(second)
	var active_nonblocking := _get_active_transition()
	assert_true(active_nonblocking.started)

	# When: Another screen is pushed.
	await _do_push()

	# Then: The non-blocking transition was also reset.
	assert_true(active_nonblocking.was_reset)


func test_interrupt_stops_without_reset_when_configured():
	# Given: A blocking enter transition with reset_on_interrupt disabled.
	var first := _create_screen(MockTransition.new())
	first.block_on_enter = true
	await _do_push(first)
	var active := _get_active_transition()
	active.reset_on_interrupt = false
	assert_true(active.started)

	# When: Another screen is pushed (which stops active transitions).
	await _do_push()

	# Then: The transition was stopped but not reset.
	assert_true(active.stopped)
	assert_false(active.was_reset)


func test_push_all_pushes_multiple_screens():
	# Given: Three screens and scenes.
	var screens: Array[Screen] = [
		_create_screen(),
		_create_screen(),
		_create_screen(),
	]
	var instances: Array[Node] = [
		Control.new(),
		Control.new(),
		Control.new(),
	]

	# When: push_all is called with multiple screens.
	_manager.push_all(screens, false, instances)
	await wait_idle_frames(1)

	# Then: All screens are on the stack.
	assert_eq(_manager.get_depth(), 3)
	assert_true(_manager.is_current(screens[2]))
	assert_eq(_manager.get_at(0), screens[0])
	assert_eq(_manager.get_at(1), screens[1])


func test_push_all_skips_intermediate_transitions():
	# Given: Screens with blocking transitions.
	var screens: Array[Screen] = []
	var instances: Array[Node] = []
	for i in range(3):
		var s := _create_screen(MockTransition.new())
		s.block_on_enter = true
		screens.append(s)
		instances.append(Control.new())

	# When: push_all is called without animate_intermediate.
	_manager.push_all(screens, false, instances)
	await wait_idle_frames(1)

	# Then: Only the last transition was started.
	assert_eq(
		_manager._transitions._active_transitions.size(),
		1,
	)
	assert_true(_get_active_transition().started)


func test_push_all_with_animate_intermediate_plays_all():
	# Given: Screens with non-blocking transitions.
	var screens: Array[Screen] = []
	var instances: Array[Node] = []
	for i in range(3):
		screens.append(_create_screen(MockTransition.new()))
		instances.append(Control.new())

	# When: push_all is called with animate_intermediate=true.
	_manager.push_all(screens, true, instances)
	await wait_idle_frames(1)

	# Then: All transitions were started.
	assert_true(_get_active_transition(0).started)
	assert_true(_get_active_transition(1).started)
	assert_true(_get_active_transition(2).started)


func test_pop_to_skips_intermediate_transitions():
	# Given: Three screens with blocking exit transitions.
	var screens: Array[Screen] = []
	for i in range(3):
		var s := _create_screen(null, MockTransition.new())
		s.block_on_exit = true
		screens.append(s)
	for s in screens:
		await _do_push(s)

	# When: pop_to is called to the first screen.
	_manager.pop_to(screens[0], false)
	await wait_idle_frames(1)

	# Then: Only the topmost exit transition was started.
	assert_eq(
		_manager._transitions._active_transitions.size(),
		1,
	)
	assert_true(_get_active_transition().started)


func test_pop_to_with_animate_intermediate_plays_all():
	# Given: Three screens with non-blocking exit transitions.
	var screens: Array[Screen] = []
	for i in range(3):
		screens.append(_create_screen(null, MockTransition.new()))
	for s in screens:
		await _do_push(s)

	# When: pop_to is called with animate_intermediate=true.
	_manager.pop_to(screens[0], true)
	await wait_idle_frames(1)

	# Then: All exit transitions were started (except the first).
	assert_eq(
		_manager._transitions._active_transitions.size(),
		2,
	)
	assert_true(_get_active_transition(0).started)
	assert_true(_get_active_transition(1).started)


func test_process_mode_disabled_when_covered_and_restored_on_pop():
	# Given: A screen with pause_when_covered=true (default).
	var first := _create_screen()
	first.pause_when_covered = true
	var first_scene := Control.new()
	await _do_push(first, first_scene)

	# When: A second screen is pushed.
	await _do_push()

	# Then: The first scene's process mode is disabled.
	assert_eq(first_scene.process_mode, Node.PROCESS_MODE_DISABLED)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The first scene's process mode is restored.
	assert_eq(first_scene.process_mode, Node.PROCESS_MODE_INHERIT)

	# Given: A screen with pause_when_covered=false.
	var second := _create_screen()
	second.pause_when_covered = false
	var second_scene := Control.new()
	await _do_push(second, second_scene)

	# When: A third screen is pushed.
	await _do_push()

	# Then: The second scene's process mode is unchanged.
	assert_ne(second_scene.process_mode, Node.PROCESS_MODE_DISABLED)


func test_interrupted_exit_frees_scene():
	# Given: Two screens; the second has a non-blocking exit transition.
	await _do_push()
	var second := _create_screen(null, MockTransition.new())
	var second_scene := Control.new()
	await _do_push(second, second_scene)

	# When: The second screen is popped then a third is pushed.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.started)
	await _do_push()
	await wait_idle_frames(1)

	# Then: The second scene is freed and transition was reset.
	assert_freed(second_scene, "popped scene")
	assert_true(active.was_reset)


func test_interrupted_exit_stops_without_reset_when_configured():
	# Given: A non-blocking exit with reset_on_interrupt disabled.
	await _do_push()
	var second := _create_screen(null, MockTransition.new())
	var second_scene := Control.new()
	await _do_push(second, second_scene)

	# When: The second screen is popped then a third is pushed.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	active.reset_on_interrupt = false
	await _do_push()
	await wait_idle_frames(1)

	# Then: The transition was stopped but not reset; scene freed.
	assert_true(active.stopped)
	assert_false(active.was_reset)
	assert_freed(second_scene, "popped scene")


func test_duplicate_screen_push_is_dropped():
	# Given: A manager with one screen.
	var screen := _create_screen()
	await _do_push(screen)

	# When: The same screen is pushed again.
	var dup: Control = autofree(Control.new())
	_manager.push(screen, dup)
	await wait_idle_frames(1)

	# Then: The stack depth remains 1.
	assert_eq(_manager.get_depth(), 1)


func test_queued_operations_from_signal_handlers():
	# Given: A handler that pushes a second screen on screen_pushed.
	var first := _create_screen()
	var second := _create_screen()
	_manager.screen_pushed.connect(
		func(_s): _manager.push(second, Control.new()),
		CONNECT_ONE_SHOT,
	)

	# When: The first screen is pushed.
	await _do_push(first)
	await wait_idle_frames(1)

	# Then: Both screens are on the stack in order.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_at(0), first)
	assert_eq(_manager.get_at(1), second)

	# Given: A handler that pops on the next push.
	_manager.screen_pushed.connect(
		func(_s): _manager.pop(),
		CONNECT_ONE_SHOT,
	)

	# When: A third screen is pushed.
	await _do_push()
	await wait_idle_frames(1)

	# Then: The third was pushed then popped; stack is [first, second].
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_at(0), first)
	assert_eq(_manager.get_at(1), second)


func test_pop_to_depth_noop_when_at_target():
	# Given: A manager with two screens.
	await _do_push()
	await _do_push()
	watch_signals(_manager)

	# When: pop_to_depth is called with the current depth.
	_manager.pop_to_depth(2)
	await wait_idle_frames(1)

	# Then: No signals are emitted and stack is unchanged.
	assert_signal_not_emitted(_manager, "screen_exiting")
	assert_eq(_manager.get_depth(), 2)


func test_push_wraps_scene_in_overlay_with_mouse_stop():
	# Given: A screen manager.
	var scene := Control.new()

	# When: A screen is pushed.
	await _do_push(null, scene)

	# Then: The scene's parent is a StdScreenOverlay with MOUSE_FILTER_STOP.
	var overlay := scene.get_parent() as Overlay
	assert_true(overlay is Overlay)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_push_overlay_sharing_depends_on_block_input():
	# Given: A manager with one screen.
	var first_scene := Control.new()
	await _do_push(null, first_scene)

	# When: A non-blocking screen is pushed.
	var nb := _create_screen(null, null, false)
	var nb_scene := Control.new()
	await _do_push(nb, nb_scene)

	# Then: Both scenes share the same overlay parent.
	assert_same(first_scene.get_parent(), nb_scene.get_parent())

	# When: A blocking screen is pushed (default).
	var blocking_scene := Control.new()
	await _do_push(null, blocking_scene)

	# Then: The blocking screen has its own overlay.
	assert_ne(first_scene.get_parent(), blocking_scene.get_parent())
	assert_true(blocking_scene.get_parent() is Overlay)


func test_pop_frees_unshared_overlay_preserves_shared():
	# Given: A manager with two blocking screens.
	await _do_push()
	var second_scene := Control.new()
	await _do_push(null, second_scene)
	var unshared := second_scene.get_parent()

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The unshared overlay is freed.
	assert_freed(unshared, "unshared overlay")

	# Given: A base screen and a non-blocking screen.
	var base_scene := Control.new()
	await _do_push(null, base_scene)
	var nb := _create_screen(null, null, false)
	await _do_push(nb)
	var shared := base_scene.get_parent()

	# When: The non-blocking screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The shared overlay survives.
	assert_not_freed(shared, "shared overlay")


func test_close_requested_cancellation_aborts_close():
	# Given: Two screens where the top has close_action.
	await _do_push()
	var top := _create_screen()
	top.close_action = &"ui_cancel"
	await _do_push(top)
	top.close_requested.connect(
		func(_event: InputEvent, cancel: Callable) -> void: cancel.call(),
	)

	# When: The close action is simulated.
	_manager._request_close_overlay(InputEventKey.new())
	await wait_idle_frames(1)

	# Then: The stack is unchanged (close was cancelled).
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(top))


func test_push_emits_lifecycle_signals_in_order():
	# Given: A manager with one screen and signal order tracking.
	var first_screen := _create_screen()
	var first_scene := Control.new()
	await _do_push(first_screen, first_scene)

	var second_screen := _create_screen()
	var second_scene := Control.new()
	var order: Array[String] = []
	_manager.screen_entering.connect(func(_s, _sc): order.append("entering"))
	_manager.screen_entered.connect(func(_s, _sc): order.append("entered"))
	_manager.screen_covered.connect(func(_s, _sc): order.append("covered"))
	_manager.screen_pushed.connect(func(_s): order.append("pushed"))
	watch_signals(_manager)

	# When: A second screen is pushed.
	await _do_push(second_screen, second_scene)

	# Then: Signals fire in the correct order with correct parameters.
	assert_eq(order, ["entering", "entered", "covered", "pushed"])
	assert_signal_emitted_with_parameters(
		_manager, "screen_entering", [second_screen, second_scene]
	)
	assert_signal_emitted_with_parameters(
		_manager, "screen_entered", [second_screen, second_scene]
	)
	assert_signal_emitted_with_parameters(
		_manager, "screen_covered", [first_screen, first_scene]
	)
	assert_signal_emitted_with_parameters(_manager, "screen_pushed", [second_screen])


func test_pop_emits_lifecycle_signals_in_order():
	# Given: A manager with two screens.
	var first := _create_screen()
	var first_scene := Control.new()
	await _do_push(first, first_scene)
	var second := _create_screen()
	var second_scene := Control.new()
	await _do_push(second, second_scene)

	var order: Array[String] = []
	_manager.screen_exiting.connect(func(_s, _sc): order.append("exiting"))
	_manager.screen_uncovered.connect(func(_s, _sc): order.append("uncovered"))
	_manager.screen_exited.connect(func(_s, _sc): order.append("exited"))
	_manager.screen_popped.connect(func(_s): order.append("popped"))
	watch_signals(_manager)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Signals fire in the correct order with correct parameters.
	assert_eq(order, ["exiting", "uncovered", "exited", "popped"])
	assert_signal_emitted_with_parameters(
		_manager, "screen_exiting", [second, second_scene]
	)
	assert_signal_emitted_with_parameters(
		_manager, "screen_exited", [second, second_scene]
	)
	assert_signal_emitted_with_parameters(
		_manager, "screen_uncovered", [first, first_scene]
	)
	assert_signal_emitted_with_parameters(_manager, "screen_popped", [second])


func test_replace_emits_lifecycle_in_correct_order():
	# Given: A manager with one screen.
	var old_screen := _create_screen()
	await _do_push(old_screen)
	var order: Array[String] = []
	_manager.screen_exiting.connect(func(_s, _sc): order.append("exiting"))
	_manager.screen_exited.connect(func(_s, _sc): order.append("exited"))
	_manager.screen_entering.connect(func(_s, _sc): order.append("entering"))
	_manager.screen_entered.connect(func(_s, _sc): order.append("entered"))
	_manager.screen_replaced.connect(func(_o, _n): order.append("replaced"))
	watch_signals(_manager)

	# When: The top is replaced.
	var new_screen := _create_screen()
	_manager.replace(new_screen, Control.new())
	await wait_idle_frames(1)

	# Then: Signals fire in the correct order with correct parameters.
	assert_eq(
		order,
		["exiting", "exited", "entering", "entered", "replaced"],
	)
	assert_signal_emitted_with_parameters(
		_manager, "screen_replaced", [old_screen, new_screen]
	)


func test_reset_emits_lifecycle_for_all_screens():
	# Given: A manager with three screens.
	var screens: Array[Screen] = [
		_create_screen(),
		_create_screen(),
		_create_screen(),
	]
	for s in screens:
		await _do_push(s)
	var exiting_screens: Array[Screen] = []
	var popped_screens: Array[Screen] = []
	var order: Array[String] = []
	_manager.screen_exiting.connect(func(s, _sc): exiting_screens.append(s))
	_manager.screen_exiting.connect(func(_s, _sc): order.append("exiting"))
	_manager.screen_exited.connect(func(_s, _sc): order.append("exited"))
	_manager.screen_popped.connect(func(s): popped_screens.append(s))
	_manager.screen_popped.connect(func(_s): order.append("popped"))

	# When: The stack is reset.
	_manager.reset(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: All three received exiting in reverse stack order, each followed by exited.
	assert_eq(exiting_screens, [screens[2], screens[1], screens[0]])
	assert_eq(order[0], "exiting")
	assert_eq(order[1], "exited")

	# Then: screen_popped is emitted for all three in reverse order.
	assert_eq(popped_screens, [screens[2], screens[1], screens[0]])


func test_screen_signals_emitted_on_push_and_pop():
	# Given: A base screen and a tracked screen.
	await _do_push()
	var screen := _create_screen()
	watch_signals(screen)

	# When: The screen is pushed.
	await _do_push(screen)

	# Then: Push lifecycle signals were emitted on the screen.
	assert_signal_emitted(screen, "entering")
	assert_signal_emitted(screen, "entered")

	# When: The screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Pop lifecycle signals were emitted on the screen.
	assert_signal_emitted(screen, "exiting")
	assert_signal_emitted(screen, "exited")


func test_pop_with_blocking_exit_delays_popped_signal():
	# Given: Two screens; second has blocking exit.
	await _do_push()
	var second := _create_screen(null, MockTransition.new())
	second.block_on_exit = true
	await _do_push(second)
	watch_signals(_manager)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.started)
	assert_signal_not_emitted(_manager, "screen_popped")

	# When: The transition completes.
	active.complete()
	await wait_idle_frames(1)

	# Then: The popped signal is emitted.
	assert_signal_emitted(_manager, "screen_popped")


func test_replace_with_blocking_exit_delays_new_screen():
	# Given: A screen with a blocking exit transition.
	var original := _create_screen(null, MockTransition.new())
	original.block_on_exit = true
	await _do_push(original)
	watch_signals(_manager)

	# When: The top is replaced.
	_manager.replace(_create_screen(), Control.new())
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.started)
	assert_signal_not_emitted(_manager, "screen_entering")

	# When: The transition completes.
	active.complete()
	await wait_idle_frames(1)

	# Then: The new screen has entered.
	assert_signal_emitted(_manager, "screen_entered")
	assert_signal_emitted(_manager, "screen_replaced")


func test_pop_nonblocking_exit_emits_exited_before_popped():
	# Given: Two screens; second has a non-blocking exit transition.
	await _do_push()
	var second := _create_screen(null, MockTransition.new())
	await _do_push(second)
	var order: Array[String] = []
	_manager.screen_exited.connect(func(_s, _sc): order.append("exited"))
	_manager.screen_popped.connect(func(_s): order.append("popped"))

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.started)

	# Then: Neither exited nor popped has fired yet (non-blocking defers).
	assert_eq(order, [])

	# When: The transition completes.
	active.complete()
	await wait_idle_frames(1)

	# Then: exited fires before popped.
	assert_eq(order, ["exited", "popped"])


func test_focus_saved_and_restored_on_pop():
	# Given: A first screen with a focusable button.
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)
	button.grab_focus()
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)

	# When: A second screen is pushed, then popped.
	await _do_push()
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button.
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)


func test_focus_restored_on_pop_even_when_focus_mode_cleared():
	# Given: A first screen with a focusable button.
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(null, first_scene)
	button.grab_focus()

	# Given: A handler simulating focus handler behavior.
	var cursor := (
		StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR) as StdInputCursor
	)
	cursor.focus_root_changed.connect(
		func(root: Control) -> void:
			if root and not root.is_ancestor_of(button):
				button.focus_mode = Control.FOCUS_NONE
			else:
				button.focus_mode = Control.FOCUS_ALL,
	)

	# When: A second screen is pushed (button outside focus root).
	await _do_push()
	assert_eq(button.focus_mode, Control.FOCUS_NONE)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button.
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)


func test_overlay_config_aggregates_across_screens():
	# Given: A base screen with close_action and click_to_close.
	var base := _create_screen()
	base.close_action = &"ui_cancel"
	base.overlay_click_to_close = 1
	var base_scene := Control.new()
	await _do_push(base, base_scene)

	# When: A non-blocking screen is pushed into the same overlay.
	var second := _create_screen(null, null, false)
	second.close_action = &"ui_back"
	second.overlay_click_to_close = 2
	await _do_push(second)

	# Then: The overlay click_to_close mask is the OR of both (3).
	var overlay := base_scene.get_parent() as Overlay
	assert_eq(overlay.click_to_close, 3)

	# Then: Both close actions are present.
	assert_has(_manager._close_actions, "ui_cancel")
	assert_has(_manager._close_actions, "ui_back")


func test_close_requested_propagates_topmost_first():
	# Given: A base and two non-blocking screens in the same overlay.
	var base := _create_screen()
	base.close_action = &"ui_cancel"
	await _do_push(base)
	var second := _create_screen(null, null, false)
	await _do_push(second)
	var third := _create_screen(null, null, false)
	await _do_push(third)

	# Connect close_requested handlers that record order.
	var order: Array[Screen] = []
	base.close_requested.connect(func(_e, _c): order.append(base))
	second.close_requested.connect(func(_e, _c): order.append(second))
	third.close_requested.connect(func(_e, _c): order.append(third))

	# When: A close is requested.
	_manager._request_close_overlay(InputEventKey.new())
	await wait_idle_frames(1)

	# Then: Propagation was topmost-first and all overlay screens popped.
	assert_eq(order, [third, second, base])
	assert_eq(_manager.get_depth(), 1)


func test_close_animate_intermediate_plays_exit_transitions():
	# Given: A base screen with close_animate_intermediate enabled.
	var base := _create_screen()
	base.close_action = &"ui_cancel"
	base.close_animate_intermediate = true
	await _do_push(base)

	# Given: Two non-blocking screens with exit transitions.
	var second := _create_screen(null, MockTransition.new(), false)
	await _do_push(second)
	var third := _create_screen(null, MockTransition.new(), false)
	await _do_push(third)

	# When: A close is requested.
	_manager._request_close_overlay(InputEventKey.new())
	await wait_idle_frames(1)

	# Then: Both exit transitions were started.
	assert_true(_get_active_transition(0).started)
	assert_true(_get_active_transition(1).started)


func test_duplicate_replace_rejected():
	# Given: A manager with two screens.
	var first := _create_screen()
	var second := _create_screen()
	await _do_push(first)
	await _do_push(second)

	# When: The top is replaced with the first (already in stack).
	var dup: Control = autofree(Control.new())
	_manager.replace(first, dup)
	await wait_idle_frames(1)

	# Then: The stack is unchanged.
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(second))


func test_exit_tree_stops_transitions_and_clears_queue():
	# Given: A screen with a blocking enter transition.
	var screen := _create_screen(MockTransition.new())
	screen.block_on_enter = true
	await _do_push(screen)
	var active := _get_active_transition()
	assert_true(active.started)

	# When: The manager is removed from the tree.
	_manager.get_parent().remove_child(_manager)

	# Then: The transition was force-reset and the queue is cleared.
	assert_true(active.was_reset)
	assert_eq(_manager._queue._queue.size(), 0)

	# Cleanup: re-add so autofree works.
	add_child(_manager)


func test_teardown_frees_retained_nodes():
	# Given: A manager with retained nodes.
	var node_a := Control.new()
	var node_b := Control.new()
	_manager._retained_nodes[&"a"] = node_a
	_manager._retained_nodes[&"b"] = node_b

	# When: The manager is removed from the tree (triggers teardown).
	_manager.get_parent().remove_child(_manager)
	await wait_idle_frames(1)

	# Then: The retained nodes are freed and the dictionary is cleared.
	assert_freed(node_a, "retained node a")
	assert_freed(node_b, "retained node b")
	assert_eq(_manager._retained_nodes.size(), 0)

	add_child(_manager)  # NOTE: Re-add so autofree works.


func test_reset_clears_retained_nodes():
	# Given: A manager with a screen and retained nodes.
	await _do_push()
	var retained := Control.new()
	_manager._retained_nodes[&"test"] = retained

	# When: The stack is reset.
	_manager.reset(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: The retained node is freed and the dictionary is cleared.
	assert_freed(retained, "retained node")
	assert_eq(_manager._retained_nodes.size(), 0)


func test_self_replace_supported():
	# Given: A manager with one screen.
	var screen := _create_screen()
	var first_scene := Control.new()
	await _do_push(screen, first_scene)
	var overlay := first_scene.get_parent() as Overlay
	watch_signals(_manager)

	# When: The top is replaced with the same screen and a new scene.
	var new_scene := Control.new()
	_manager.replace(screen, new_scene)
	await wait_idle_frames(1)

	# Then: The stack has depth 1 with the same screen and new scene.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))
	assert_eq(_manager.get_scene(), new_scene)
	assert_signal_emitted_with_parameters(_manager, "screen_replaced", [screen, screen])

	# Then: The overlay instance is reused (not freed and recreated).
	assert_not_freed(overlay, "reused overlay")
	assert_same(new_scene.get_parent(), overlay)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_screen(
	transition_enter: StdScreenTransition = null,
	transition_exit: StdScreenTransition = null,
	block_input_below: bool = true,
) -> Screen:
	var screen := Screen.new()
	screen.transition_enter = transition_enter
	screen.transition_exit = transition_exit
	screen.block_input_below = block_input_below
	return screen


func _do_push(screen: Screen = null, scene: Control = null) -> void:
	if not screen:
		screen = _create_screen()
	if not scene:
		scene = Control.new()
	_manager.push(screen, scene)
	await wait_idle_frames(1)


func _get_active_transition(
	index: int = 0,
) -> MockTransition:
	return _manager._transitions._active_transitions[index]
