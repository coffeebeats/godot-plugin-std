##
## screen/manager/manager_test.gd
##
## Tests pertaining to `StdScreenManager`: stack operations, process modes, transitions,
## sounds and teardown. Input isolation, focus and attachments are covered by the
## sibling `manager_*_test.gd` files.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Screen := preload("../screen.gd")
const TransitionTests := preload("../transition_test.gd")
const Manager := preload("manager.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null
var _sound_player = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_process_mode_disabled_when_covered_and_restored_on_pop():
	# Given: A screen with pause_when_covered=true.
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

	# When: pop(null, true) is called with force.
	_manager.pop(null, true)
	await wait_idle_frames(1)

	# Then: The screen was popped.
	assert_eq(_manager.get_depth(), 1)


func test_is_current_matches_topmost_screen():
	# Given: Two screens pushed onto the stack.
	var first := _create_screen()
	var second := _create_screen()
	await _do_push(first)
	await _do_push(second)

	# Then: Only the topmost screen reports as current.
	assert_true(_manager.is_current(second))
	assert_false(_manager.is_current(first))


func test_transition_push_overrides_default_transition():
	# Given: A screen with both transition and transition_push set.
	# The two transitions use different block_input values so the
	# active duplicate can be traced back to its source.
	var default_tx := MockTransition.new()
	default_tx.block_input = true
	var push_tx := MockTransition.new()
	push_tx.block_input = false
	var screen := _create_screen(default_tx)
	screen.transition_push = push_tx
	await _do_push(screen)

	# Then: The push-specific transition was used.
	var active := _get_active_transition()
	assert_true(active is MockTransition)
	assert_true(active.push_started)
	assert_false(
		active.block_input,
		"active should be a duplicate of push_tx",
	)


func test_transition_pop_overrides_default_transition():
	# Given: Two screens; the top has transition_pop set.
	# Different block_input values distinguish the transitions.
	var default_tx := MockTransition.new()
	default_tx.block_input = true
	var pop_tx := MockTransition.new()
	pop_tx.block_input = false
	await _do_push()
	var screen := _create_screen(default_tx)
	screen.transition_pop = pop_tx
	await _do_push(screen)

	# Complete the push transition so the screen is fully entered.
	var push_active := _get_active_transition()
	push_active.do_mount()
	push_active.complete()
	await wait_idle_frames(1)

	# When: The screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The pop-specific transition was used.
	var active := _get_active_transition()
	assert_true(active is MockTransition)
	assert_true(active.pop_started)
	assert_false(
		active.block_input,
		"active should be a duplicate of pop_tx",
	)


func test_replace_uses_transition_push_override():
	# Given: A screen with transition_push set and a different
	# default. block_input distinguishes the two.
	var default_tx := MockTransition.new()
	default_tx.block_input = true
	var push_tx := MockTransition.new()
	push_tx.block_input = false
	await _do_push()
	var screen := _create_screen(default_tx)
	screen.transition_push = push_tx

	# When: The top screen is replaced with screen.
	_manager.replace(screen, Control.new())
	await wait_idle_frames(1)

	# Then: The push-specific transition was used for replace.
	var active := _get_active_transition()
	assert_true(active is MockTransition)
	assert_true(active.replace_started)
	assert_false(
		active.block_input,
		"replace should use transition_push",
	)


func test_push_plays_enter_sound():
	# Given: A screen with an enter sound.
	var screen := _create_screen()
	var sound := StdSoundEvent.new()
	screen.sound_enter = sound

	# When: The screen is pushed.
	await _do_push(screen)

	# Then: The enter sound was played.
	assert_called(_sound_player, "play")
	var params = get_call_parameters(_sound_player, "play")
	assert_eq(params[0], sound)


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


func test_exit_tree_emits_lifecycle_signals_for_active_scenes():
	# Given: Two screens on the stack.
	var first := _create_screen()
	var second := _create_screen()
	await _do_push(first)
	await _do_push(second)

	# Given: Signal watchers.
	watch_signals(first)
	watch_signals(second)
	watch_signals(_manager)

	# When: The manager is removed from the tree.
	_manager.get_parent().remove_child(_manager)

	# Then: Both screens emitted exiting, exited, and popped.
	assert_signal_emitted(second, "exiting")
	assert_signal_emitted(second, "exited")
	assert_signal_emitted(second, "popped")
	assert_signal_emitted(first, "exiting")
	assert_signal_emitted(first, "exited")
	assert_signal_emitted(first, "popped")
	assert_signal_emitted(_manager, "screen_exiting")
	assert_signal_emitted(_manager, "screen_exited")


func test_exit_tree_frees_cached_scenes():
	# Given: A base screen on the stack.
	await _do_push()

	# Given: A screen with cache_instance enabled, pushed on top.
	var screen := _create_screen()
	screen.cache_instance = true
	var scene := Control.new()
	await _do_push(screen, scene)

	# When: The cached screen is popped (scene is cached, not freed).
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The scene is cached, not freed.
	assert_not_freed(scene, "cached scene")

	# When: The manager is removed from the tree.
	_manager.get_parent().remove_child(_manager)

	# Then: The cached scene is freed immediately.
	assert_freed(scene, "cached scene after teardown")


func test_exit_tree_marks_active_scenes_for_deletion():
	# Given: A screen on the stack.
	var scene := Control.new()
	await _do_push(null, scene)

	# When: The manager is removed from the tree.
	_manager.get_parent().remove_child(_manager)

	# Then: The active scene is queued for deletion.
	assert_true(
		scene.is_queued_for_deletion(),
		"active scene should be queued for deletion",
	)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)

	_sound_player = autofree(double(StdSoundEventPlayer).new())
	stub(_sound_player, "play").to_return(StdSoundInstance.new())
	_manager._sound_player = _sound_player


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
