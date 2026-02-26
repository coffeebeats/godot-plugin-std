##
## std/screen/pusher_test.gd
##
## Tests pertaining to `StdScreenPusher`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Pusher := preload("pusher.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_ACTIONS := [&"test_push", &"test_close", &"test_toggle"]
const _TEST_SCENE_PATH := "res://screen/_test_scene.tscn"

var _manager: StdScreenManager = null
var _test_scene: PackedScene = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_action_pushes_screen():
	# Given: A base screen and a pusher with a push action.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [&"test_push"], [])

	# When: The push action is simulated.
	_simulate_action(pusher, &"test_push")
	await wait_idle_frames(1)

	# Then: The target screen was pushed.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), target)


func test_close_action_pops_screen_when_current():
	# Given: A base screen and a pushed target with close action.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [], [&"test_close"])
	await _do_push(target)

	# When: The close action is simulated.
	_simulate_action(pusher, &"test_close")
	await wait_idle_frames(1)

	# Then: The target screen was popped.
	assert_eq(_manager.get_depth(), 1)


func test_close_action_ignored_when_not_current():
	# Given: A base, target, and a third screen covering the target.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [], [&"test_close"])
	await _do_push(target)
	await _do_push()

	# When: The close action is simulated.
	_simulate_action(pusher, &"test_close")
	await wait_idle_frames(1)

	# Then: The stack is unchanged (close was ignored).
	assert_eq(_manager.get_depth(), 3)


func test_push_action_ignored_when_in_stack():
	# Given: A base screen and a pushed target with push action.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [&"test_push"], [])
	await _do_push(target)

	# When: The push action is simulated.
	_simulate_action(pusher, &"test_push")
	await wait_idle_frames(1)

	# Then: The stack is unchanged (push was ignored).
	assert_eq(_manager.get_depth(), 2)


func test_toggle_action_pushes_when_absent_pops_when_current():
	# Given: A pusher with the same action for push and close.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [&"test_toggle"], [&"test_toggle"])

	# When: The toggle action fires (screen absent).
	_simulate_action(pusher, &"test_toggle")
	await wait_idle_frames(1)

	# Then: The screen is pushed.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), target)

	# When: The toggle action fires again (screen current).
	_simulate_action(pusher, &"test_toggle")
	await wait_idle_frames(1)

	# Then: The screen is popped.
	assert_eq(_manager.get_depth(), 1)


func test_close_action_works_after_screen_uncovered():
	# Given: A pushed target covered by another screen.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [], [&"test_close"])
	await _do_push(target)
	await _do_push()

	# When: The covering screen is popped and close is simulated.
	_manager.pop(true)
	await wait_idle_frames(1)
	_simulate_action(pusher, &"test_close")
	await wait_idle_frames(1)

	# Then: The target was popped (close worked after uncover).
	assert_eq(_manager.get_depth(), 1)


func test_finds_manager_via_ancestor_walk():
	# Given: A pusher added as a child of the manager.
	await _do_push()
	var target := _create_screen()
	var pusher := Pusher.new()
	pusher.screen = target
	_manager.add_child(pusher)

	# Then: The pusher found the manager.
	assert_same(pusher.manager, _manager)


func test_uses_manager_path_when_set():
	# Given: A pusher with an explicit manager_path.
	await _do_push()
	var target := _create_screen()
	var pusher := Pusher.new()
	pusher.screen = target
	pusher.manager_path = _manager.get_path()
	add_child_autofree(pusher)

	# Then: The pusher resolved the manager via path.
	assert_same(pusher.manager, _manager)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.erase_action(action)

	if _test_scene:
		_test_scene.take_over_path("")
		_test_scene = null


func before_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.add_action(action)

	_test_scene = PackedScene.new()
	var ctrl := Control.new()
	_test_scene.pack(ctrl)
	ctrl.free()
	_test_scene.take_over_path(_TEST_SCENE_PATH)


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = StdScreenManager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_screen(
	transition: StdScreenTransition = null,
	block_input_below: bool = true,
) -> StdScreen:
	var screen := StdScreen.new()
	screen.scene_path = _TEST_SCENE_PATH
	screen.transition = transition
	screen.block_input_below = block_input_below
	return screen


func _create_pusher(
	screen: StdScreen,
	p_push_actions: Array[StringName],
	p_pop_actions: Array[StringName],
) -> Pusher:
	var pusher := Pusher.new()
	pusher.screen = screen
	pusher.push_actions = p_push_actions
	pusher.pop_actions = p_pop_actions

	# Add as child of the manager so ancestor walk finds it.
	_manager.add_child(pusher)

	return pusher


func _do_push(
	screen: StdScreen = null,
	scene: Control = null,
) -> void:
	if not screen:
		screen = _create_screen()
	if not scene:
		scene = Control.new()
	_manager.push(screen, scene)
	await wait_idle_frames(1)


func _simulate_action(
	pusher: Pusher,
	action: StringName,
) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	pusher._unhandled_input(event)
