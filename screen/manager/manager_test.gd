# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines

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

	var push_started := false
	var pop_started := false
	var replace_started := false
	var stopped := false

	var _ctx: StdScreenTransitionContext

	func _push(context: StdScreenTransitionContext) -> void:
		_ctx = context
		push_started = true

	func _pop(context: StdScreenTransitionContext) -> void:
		_ctx = context
		pop_started = true

	func _replace(context: StdScreenTransitionContext) -> void:
		_ctx = context
		replace_started = true

	func _stop() -> void:
		stopped = true

	## complete triggers transition completion from tests.
	func complete() -> void:
		_ctx.done()

	## do_swap calls swap on the context (for testing lifecycle).
	func do_swap() -> void:
		_ctx.swap()

	## do_mount calls mount on the context.
	func do_mount() -> void:
		_ctx.mount()

	## do_unmount calls unmount on the context.
	func do_unmount() -> void:
		_ctx.unmount()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_adds_screen_to_stack():
	# When: A screen is pushed.
	var screen := _create_screen()
	await _do_push(screen)

	# Then: The stack has one screen.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), screen)


func test_push_with_transition_emits_entered_after_done():
	# Given: A screen with a push transition.
	var transition := MockTransition.new()
	var screen := _create_screen(transition)
	watch_signals(_manager)

	# When: A screen with transition is pushed.
	await _do_push(screen)

	# Then: The transition has started but entered not yet emitted.
	var active := _get_active_transition()
	assert_true(active.push_started)
	assert_signal_not_emitted(_manager, "screen_entered")

	# When: The transition performs swap and completes.
	active.do_swap()
	active.complete()
	await wait_idle_frames(1)

	# Then: The entered signal is emitted.
	assert_signal_emitted(_manager, "screen_entered")


func test_push_without_transition_emits_entered_immediately():
	# Given: A screen without a transition.
	var screen := _create_screen()
	watch_signals(_manager)

	# When: A screen without transition is pushed.
	await _do_push(screen)

	# Then: The entered signal is emitted immediately.
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
	assert_eq(_manager.get_current_screen(), first)


func test_replace_swaps_top_screen():
	# Given: A manager with two screens.
	var first := _create_screen()
	await _do_push(first)
	await _do_push()

	# When: The top is replaced.
	var replacement := _create_screen()
	_manager.replace(replacement, Control.new())
	await wait_idle_frames(1)

	# Then: Stack depth unchanged, new screen on top.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), replacement)
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
	assert_eq(_manager.get_current_screen(), new_base)


func test_pop_to():
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
	assert_eq(_manager.get_current_screen(), first)


func test_pop_to_skips_intermediate_transitions():
	# Given: Three screens; transitions set after push.
	var screens: Array[Screen] = []
	for i in range(3):
		screens.append(_create_screen())
	for s in screens:
		await _do_push(s)
	for s in screens:
		s.transition = MockTransition.new()

	# When: pop_to is called to the first screen.
	_manager.pop_to(screens[0])
	await wait_idle_frames(1)

	# Then: Only the last pop's exit transition is active.
	assert_not_null(_manager._active_transition)
	assert_true(_get_active_transition().pop_started)


func test_process_mode_disabled_when_covered_and_restored_on_pop():
	# Given: A screen with pause_when_covered=true.
	var first := _create_screen()
	first.pause_when_covered = true
	var first_scene := Control.new()
	await _do_push(first, first_scene)

	# When: A second screen is pushed.
	await _do_push()

	# Then: The first scene's process mode is disabled.
	assert_eq(
		first_scene.process_mode,
		Node.PROCESS_MODE_DISABLED,
	)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The first scene's process mode is restored.
	assert_eq(
		first_scene.process_mode,
		Node.PROCESS_MODE_INHERIT,
	)

	# Given: A screen with pause_when_covered=false.
	var second := _create_screen()
	second.pause_when_covered = false
	var second_scene := Control.new()
	await _do_push(second, second_scene)

	# When: A third screen is pushed.
	await _do_push()

	# Then: The second scene's process mode is unchanged.
	assert_ne(
		second_scene.process_mode,
		Node.PROCESS_MODE_DISABLED,
	)


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
	# Given: A handler that pushes a second screen on screen_entered.
	var first := _create_screen()
	var second := _create_screen()
	_manager.screen_entered.connect(
		func(_s, _sc): _manager.push(second, Control.new()),
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
	_manager.screen_entered.connect(
		func(_s, _sc): _manager.pop(),
		CONNECT_ONE_SHOT,
	)

	# When: A third screen is pushed.
	await _do_push()
	await wait_idle_frames(1)

	# Then: The third was pushed then popped.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_at(0), first)
	assert_eq(_manager.get_at(1), second)


func test_push_wraps_scene_in_overlay_with_mouse_stop():
	# Given: A screen manager.
	var scene := Control.new()

	# When: A screen is pushed.
	await _do_push(null, scene)

	# Then: The scene's parent is a StdScreenOverlay.
	var overlay := scene.get_parent() as Overlay
	assert_true(overlay is Overlay)
	assert_eq(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
	)


func test_push_overlay_sharing_depends_on_block_input():
	# Given: A manager with one screen.
	var first_scene := Control.new()
	await _do_push(null, first_scene)

	# When: A non-blocking screen is pushed.
	var nb := _create_screen(null, false)
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
	var nb := _create_screen(null, false)
	await _do_push(nb)
	var shared := base_scene.get_parent()

	# When: The non-blocking screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The shared overlay survives.
	assert_not_freed(shared, "shared overlay")


func test_pop_cancelled_by_close_requested():
	# Given: Two screens; top has a handler that cancels.
	await _do_push()
	var top := _create_screen()
	await _do_push(top)
	top.close_requested.connect(
		func(_event, cancel): cancel.call(),
	)

	# When: pop() is called (default force=false).
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The stack is unchanged (pop was cancelled).
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), top)


func test_pop_force_skips_close_requested():
	# Given: Two screens; top has a handler that cancels.
	await _do_push()
	var top := _create_screen()
	await _do_push(top)
	top.close_requested.connect(
		func(_event, cancel): cancel.call(),
	)

	# When: pop(true) is called with force.
	_manager.pop(true)
	await wait_idle_frames(1)

	# Then: The screen was popped.
	assert_eq(_manager.get_depth(), 1)


func test_push_emits_lifecycle_signals_in_order():
	# Given: A manager with one screen and signal tracking.
	var first_screen := _create_screen()
	var first_scene := Control.new()
	await _do_push(first_screen, first_scene)

	var second_screen := _create_screen()
	var second_scene := Control.new()
	var order: Array[String] = []
	_manager.screen_entering.connect(func(_s, _sc): order.append("entering"))
	_manager.screen_entered.connect(func(_s, _sc): order.append("entered"))
	_manager.screen_covered.connect(func(_s, _sc): order.append("covered"))
	watch_signals(_manager)

	# When: A second screen is pushed.
	await _do_push(second_screen, second_scene)

	# Then: Signals fire in the correct order.
	assert_eq(
		order,
		["entering", "entered", "covered"],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_entering",
		[second_screen, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_entered",
		[second_screen, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_covered",
		[first_screen, first_scene],
	)


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
	watch_signals(_manager)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Signals fire in the correct order.
	assert_eq(
		order,
		["exiting", "uncovered", "exited"],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_exiting",
		[second, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_exited",
		[second, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_uncovered",
		[first, first_scene],
	)


func test_replace_emits_lifecycle_in_correct_order():
	# Given: A manager with one screen.
	var old_screen := _create_screen()
	await _do_push(old_screen)
	var order: Array[String] = []
	_manager.screen_exiting.connect(func(_s, _sc): order.append("exiting"))
	_manager.screen_exited.connect(func(_s, _sc): order.append("exited"))
	_manager.screen_entering.connect(func(_s, _sc): order.append("entering"))
	_manager.screen_entered.connect(func(_s, _sc): order.append("entered"))
	watch_signals(_manager)

	# When: The top is replaced.
	var new_screen := _create_screen()
	_manager.replace(new_screen, Control.new())
	await wait_idle_frames(1)

	# Then: Signals fire in the correct order.
	assert_eq(
		order,
		["exiting", "exited", "entering", "entered"],
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
	var order: Array[String] = []
	_manager.screen_exiting.connect(func(s, _sc): exiting_screens.append(s))
	_manager.screen_exiting.connect(func(_s, _sc): order.append("exiting"))
	_manager.screen_exited.connect(func(_s, _sc): order.append("exited"))

	# When: The stack is reset.
	_manager.reset(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: All three received exiting in reverse order.
	assert_eq(
		exiting_screens,
		[screens[2], screens[1], screens[0]],
	)
	assert_eq(order[0], "exiting")
	assert_eq(order[1], "exited")


func test_screen_signals_emitted_on_push_and_pop():
	# Given: A base screen and a tracked screen.
	await _do_push()
	var screen := _create_screen()
	watch_signals(screen)

	# When: The screen is pushed.
	await _do_push(screen)

	# Then: Push lifecycle signals were emitted.
	assert_signal_emitted(screen, "entering")
	assert_signal_emitted(screen, "entered")

	# When: The screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Pop lifecycle signals were emitted.
	assert_signal_emitted(screen, "exiting")
	assert_signal_emitted(screen, "exited")


func test_pop_with_exit_transition_delays_exited():
	# Given: Two screens; second has a transition set after push (for exit).
	await _do_push()
	var second := _create_screen()
	await _do_push(second)
	second.transition = MockTransition.new()
	watch_signals(_manager)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.pop_started)
	assert_signal_not_emitted(_manager, "screen_exited")

	# When: The transition unmounts and completes.
	active.do_unmount()
	active.complete()
	await wait_idle_frames(1)

	# Then: The exited signal is emitted.
	assert_signal_emitted(_manager, "screen_exited")


func test_replace_with_transition_delays_new_screen():
	# Given: A screen on the stack.
	var original := _create_screen()
	await _do_push(original)
	watch_signals(_manager)

	# When: The top is replaced with a transitioning screen.
	(
		_manager
		.replace(
			_create_screen(MockTransition.new()),
			Control.new(),
		)
	)
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.replace_started)
	assert_signal_not_emitted(_manager, "screen_entered")

	# When: The transition swaps and completes.
	active.do_swap()
	active.complete()
	await wait_idle_frames(1)

	# Then: The new screen has entered.
	assert_signal_emitted(_manager, "screen_entered")


func test_focus_saved_and_restored_on_pop():
	# Given: A first screen with a focusable button.
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)
	button.grab_focus()
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)

	# When: A second screen is pushed, then popped.
	await _do_push()
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button.
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_focus_restored_on_pop_even_when_focus_mode_cleared():
	# Given: A first screen with a focused button.
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(null, first_scene)
	button.grab_focus()

	# Given: A handler that clears focus_mode when button leaves focus root.
	var cursor := _get_cursor()
	cursor.focus_root_changed.connect(
		func(root: Control) -> void:
			if root and not root.is_ancestor_of(button):
				button.focus_mode = Control.FOCUS_NONE
			else:
				button.focus_mode = Control.FOCUS_ALL,
	)

	# When: A second screen is pushed then popped.
	await _do_push()
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button.
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_pop_recalculates_hover_when_cursor_visible():
	# NOTE: SubViewport required; root viewport doesn't dispatch GUI input in headless
	# mode.
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 300)
	add_child_autofree(sv)
	sv.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)

	# Given: A manager inside the SubViewport.
	var sv_manager := Manager.new()
	sv.add_child(sv_manager)
	await wait_idle_frames(1)
	_get_cursor().show_cursor()

	# Given: A base screen with a hoverable button.
	var base := Control.new()
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = Vector2(100, 40)
	base.add_child(button)
	sv_manager.push(_create_screen(), base)
	await wait_idle_frames(1)

	# Given: The button is hovered.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 20)
	motion.relative = Vector2(50, 20)
	sv.push_input(motion)
	await get_tree().process_frame
	assert_true(
		button.is_hovered(),
		"precondition: button hovered",
	)

	# When: A second screen is pushed and mouse motion sent.
	sv_manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)
	var covered := InputEventMouseMotion.new()
	covered.position = Vector2(50, 20)
	covered.relative = Vector2.ZERO
	sv.push_input(covered)
	await get_tree().process_frame
	assert_false(
		button.is_hovered(),
		"precondition: button not hovered",
	)

	# When: The second screen is popped.
	sv_manager.pop()
	await wait_idle_frames(1)

	# Then: The button regains hover after recalculation.
	assert_true(
		button.is_hovered(),
		"button should be hovered after pop",
	)


func test_overlay_config_aggregates_across_screens():
	# Given: A base screen with click_to_close.
	var base := _create_screen()
	base.overlay_click_to_close = 1
	var base_scene := Control.new()
	await _do_push(base, base_scene)

	# When: A non-blocking screen is pushed.
	var second := _create_screen(null, false)
	second.overlay_click_to_close = 2
	await _do_push(second)

	# Then: The overlay mask is the OR of both (3).
	var overlay := base_scene.get_parent() as Overlay
	assert_eq(overlay.click_to_close, 3)


func test_close_requested_propagates_topmost_first():
	# Given: A base and two non-blocking screens.
	var base := _create_screen()
	await _do_push(base)
	var second := _create_screen(null, false)
	await _do_push(second)
	var third := _create_screen(null, false)
	await _do_push(third)

	# Connect close_requested handlers that record order.
	var order: Array[Screen] = []
	base.close_requested.connect(func(_e, _c): order.append(base))
	second.close_requested.connect(func(_e, _c): order.append(second))
	third.close_requested.connect(func(_e, _c): order.append(third))

	# When: A close is requested.
	_manager._request_close_overlay(InputEventKey.new())
	await wait_idle_frames(1)

	# Then: Propagation was topmost-first and screens popped.
	assert_eq(order, [third, second, base])
	assert_eq(_manager.get_depth(), 1)


func test_duplicate_replace_rejected():
	# Given: A manager with two screens.
	var first := _create_screen()
	var second := _create_screen()
	await _do_push(first)
	await _do_push(second)

	# When: The top is replaced with first (already in stack).
	var dup: Control = autofree(Control.new())
	_manager.replace(first, dup)
	await wait_idle_frames(1)

	# Then: The stack is unchanged.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), second)


func test_exit_tree_stops_transitions_and_clears_queue():
	# Given: A screen with a transition.
	var screen := _create_screen(MockTransition.new())
	await _do_push(screen)
	var active := _get_active_transition()
	assert_true(active.push_started)

	# When: The manager is removed from the tree.
	_manager.get_parent().remove_child(_manager)

	# Then: The transition was stopped and the queue cleared.
	assert_true(active.stopped)
	assert_eq(_manager._queue._queue.size(), 0)

	add_child(_manager)


func test_self_replace_supported():
	# Given: A manager with one screen.
	var screen := _create_screen()
	var first_scene := Control.new()
	await _do_push(screen, first_scene)
	var overlay := first_scene.get_parent() as Overlay
	watch_signals(_manager)

	# When: The top is replaced with the same screen.
	var new_scene := Control.new()
	_manager.replace(screen, new_scene)
	await wait_idle_frames(1)

	# Then: Depth 1 with the same screen and new scene.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), screen)
	assert_eq(_manager.get_scene(), new_scene)

	# Then: The overlay instance is reused.
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
	transition: StdScreenTransition = null,
	block_input_below: bool = true,
) -> Screen:
	var screen := Screen.new()
	screen.transition = transition
	screen.block_input_below = block_input_below
	return screen


func _do_push(
	screen: Screen = null,
	scene: Control = null,
) -> void:
	if not screen:
		screen = _create_screen()
	if not scene:
		scene = Control.new()
	_manager.push(screen, scene)
	await wait_idle_frames(1)


func _get_active_transition() -> MockTransition:
	return _manager._active_transition


func _get_cursor() -> StdInputCursor:
	return (
		StdGroup
		.get_sole_member(
			StdInputCursor.GROUP_INPUT_CURSOR,
		)
	)
