##
## screen/manager/manager_close_test.gd
##
## Tests pertaining to how `StdScreenManager` closes screens in response to input: an
## overlay background click, and a screen's `close_actions`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Screen := preload("../screen.gd")
const TransitionTests := preload("../transition_test.gd")
const Manager := preload("manager.gd")

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

# -- DEFINITIONS --------------------------------------------------------------------- #


## _Scene stands in for a mounted scene or an outside node, recording each test action
## that reaches it and optionally handling the close action itself.
class _Scene:
	extends Control

	## handles_close marks the close action as handled, standing in for a scene that uses
	## the key itself.
	var handles_close: bool = false

	## seen receives every test action that reaches this node.
	var seen: Array[StringName] = []

	func _unhandled_input(event: InputEvent) -> void:
		for action in [_TEST_ACTION, _TEST_CLOSE_ACTION]:
			if event.is_action_pressed(action):
				seen.append(action)

		if handles_close and event.is_action_pressed(_TEST_CLOSE_ACTION):
			get_viewport().set_input_as_handled()


# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_ACTION := &"test_action"
const _TEST_CLOSE_ACTION := &"test_close_action"

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_background_click_propagates_close_requested_topmost_first():
	# Given: A base and two non-blocking screens.
	var base := _create_screen()
	await _do_push(base)
	var second := _create_screen(false)
	await _do_push(second)
	var third := _create_screen(false)
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


func test_close_action_pops_topmost_screen_with_event():
	# Given: A base screen covered by a screen listing the close action.
	await _do_push()
	var screen := _create_screen(true, [_TEST_CLOSE_ACTION])
	await _do_push(screen)

	var events: Array[InputEvent] = []
	screen.close_requested.connect(func(e, _c): events.append(e))

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: The screen popped and its handler saw the press.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(events.size(), 1)
	assert_true(events[0].is_action_pressed(_TEST_CLOSE_ACTION))


func test_close_action_is_cancelled_by_close_requested_handler():
	# Given: A closable screen whose handler cancels.
	await _do_push()
	var screen := _create_screen(true, [_TEST_CLOSE_ACTION])
	await _do_push(screen)
	screen.close_requested.connect(func(_e, cancel: Callable): cancel.call())

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: The screen is still on top.
	assert_eq(_manager.get_depth(), 2)
	assert_same(_manager.get_current_screen(), screen)


func test_close_action_is_inert_while_covered_and_restored_on_pop():
	# Given: A closable screen covered by one that is not.
	await _do_push()
	var screen := _create_screen(true, [_TEST_CLOSE_ACTION])
	await _do_push(screen)
	await _do_push()

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: Nothing popped; the covering screen does not list the action.
	assert_eq(_manager.get_depth(), 3)

	# When: The covering screen pops and the action is dispatched again.
	_manager.pop(null, true)
	await wait_idle_frames(2)
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: The closable screen popped.
	assert_eq(_manager.get_depth(), 1)


func test_close_action_in_shared_overlay_applies_to_topmost_screen_only():
	# Given: A closable screen joined in its overlay by a non-blocking screen that is not.
	await _do_push()
	var lower := _create_screen(true, [_TEST_CLOSE_ACTION])
	await _do_push(lower)
	await _do_push(_create_screen(false))

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: Nothing popped; the buried screen's actions do not apply.
	assert_eq(_manager.get_depth(), 3)

	# Given: The top screen is replaced by one that lists the action.
	_manager.pop(null, true)
	await wait_idle_frames(2)
	await _do_push(_create_screen(false, [_TEST_CLOSE_ACTION]))

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: Only the top screen popped; the rest of the shared overlay stayed.
	assert_eq(_manager.get_depth(), 2)
	assert_same(_manager.get_current_screen(), lower)


func test_close_action_is_consumed_even_when_the_overlay_does_not():
	# Given: A node that runs after the manager, and one shared overlay (which does not
	# consume unhandled input) whose top screen lists the close action.
	var outside := _Scene.new()
	add_child_autofree(outside)
	move_child(outside, 0)

	await _do_push()
	await _do_push(_create_screen(false, [_TEST_CLOSE_ACTION]))

	# When: The close action, then the plain test action, are dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)
	_dispatch_action(_TEST_ACTION)

	# Then: The screen popped, the close action never left the manager, the other did.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(outside.seen, [_TEST_ACTION])


func test_close_action_is_dropped_while_an_operation_is_in_flight():
	# Given: A closable screen on top, and a push held mid-transition above it.
	await _do_push()
	await _do_push(_create_screen(true, [_TEST_CLOSE_ACTION]))

	# NOTE: The manager runs a duplicate of the configured transition.
	_manager.push(_create_screen(true, [], MockTransition.new()), Control.new())
	await wait_idle_frames(1)
	var tx: MockTransition = _manager._active_transition
	assert_true(tx.push_started)

	# When: The close action is dispatched during the transition.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: No pop was queued; finishing the push leaves three screens.
	tx.do_mount()
	tx.complete()
	await wait_idle_frames(2)
	assert_eq(_manager.get_depth(), 3)


func test_close_action_is_ignored_on_the_last_screen():
	# Given: A lone closable screen.
	await _do_push(_create_screen(true, [_TEST_CLOSE_ACTION]))

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: The screen remains.
	assert_eq(_manager.get_depth(), 1)


func test_close_action_handled_by_scene_does_not_close():
	# Given: A closable screen whose scene handles the close action itself.
	await _do_push()
	var scene := _Scene.new()
	scene.handles_close = true
	await _do_push(_create_screen(true, [_TEST_CLOSE_ACTION]), scene)

	# When: The close action is dispatched.
	_dispatch_action(_TEST_CLOSE_ACTION)
	await wait_idle_frames(1)

	# Then: The scene kept the key and the screen is still on top.
	assert_eq(scene.seen, [_TEST_CLOSE_ACTION])
	assert_eq(_manager.get_depth(), 2)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(_TEST_ACTION)
	InputMap.erase_action(_TEST_CLOSE_ACTION)


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION)
	InputMap.add_action(_TEST_CLOSE_ACTION)


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_screen(
	block_input_below: bool = true,
	close_actions: Array[StringName] = [],
	transition: StdScreenTransition = null,
) -> Screen:
	var screen := Screen.new()
	screen.block_input_below = block_input_below
	screen.close_actions = close_actions
	screen.transition = transition
	return screen


## _dispatch_action sends an action through the engine's input handling so that ordering
## and consumption match runtime.
func _dispatch_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true

	get_tree().root.push_input(event)


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
