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
const _TEST_PUSHER_SCENE_PATH := "res://screen/_test_pusher.tscn"
const _TEST_SCREEN_PATH := "res://screen/_test_screen.tres"
const _TEST_SCENE_PATH := "res://screen/_test_scene.tscn"

var _manager: StdScreenManager = null
var _test_pusher_scene: PackedScene = null
var _test_screen: StdScreen = null
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
	_manager.pop(null, true)
	await wait_idle_frames(1)
	_simulate_action(pusher, &"test_close")
	await wait_idle_frames(1)

	# Then: The target was popped (close worked after uncover).
	assert_eq(_manager.get_depth(), 1)


func test_push_action_works_after_tree_reentry():
	# Given: A base screen and a pusher with a push action.
	await _do_push()
	var target := _create_screen()
	var pusher := _create_pusher(target, [&"test_push"], [])

	# Given: The pusher is removed from and re-added to the tree, simulating
	# a cached scene instance being reused after a pop and subsequent push.
	var parent := pusher.get_parent()
	parent.remove_child(pusher)
	parent.add_child(pusher)

	# When: The push action is simulated.
	_simulate_action(pusher, &"test_push")
	await wait_idle_frames(1)

	# Then: The target screen was pushed (signals reconnected on re-entry).
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), target)


func test_attached_pusher_pushes_and_pops_target_screen():
	# Given: A pusher scene targeting a screen, declared as another screen's attachment.
	var target := _create_screen()
	var host := _create_screen()
	host.attachment_scenes = PackedStringArray([_create_pusher_scene(target)])

	# When: The host screen is pushed.
	await _do_push(host)

	# Then: The pusher was mounted and found the manager.
	var pusher: Pusher = _manager._attachments[host][0]
	assert_same(pusher.manager, _manager)

	# When: The toggle action is simulated.
	_simulate_action(pusher, &"test_toggle")
	await wait_idle_frames(1)

	# Then: The target screen was pushed on top of the host screen.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), target)

	# When: The toggle action is simulated again, with the host screen covered.
	_simulate_action(pusher, &"test_toggle")
	await wait_idle_frames(1)

	# Then: The target screen was popped.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), host)

	# When: The host screen is torn down.
	_manager._teardown()
	await wait_idle_frames(2)

	# Then: The pusher was freed along with the screen it was attached to.
	assert_false(is_instance_valid(pusher))


func test_pusher_without_manager_is_inert():
	# Given: A base screen and a tree containing no screen manager.
	await _do_push()
	var host: Node = add_child_autofree(Node.new())

	# When: A pusher enters that tree.
	var target := _create_screen()
	var pusher := _create_pusher(target, [&"test_push"], [], host)

	# Then: The pusher disabled itself without connecting to the screen.
	assert_push_warning("No screen manager found")
	assert_null(pusher.manager)
	assert_eq(target.entering.get_connections().size(), 0)

	# When: The push action is simulated.
	_simulate_action(pusher, &"test_push")
	await wait_idle_frames(1)

	# Then: The action was ignored and no screen was pushed.
	assert_eq(_manager.get_depth(), 1)

	# When: The pusher leaves the tree.
	host.remove_child(pusher)

	# Then: Teardown is a no-op; nothing was connected to disconnect.
	assert_eq(target.entering.get_connections().size(), 0)


func test_pusher_without_manager_recovers_on_reentry():
	# Given: A pusher which entered a tree containing no screen manager.
	await _do_push()
	var host: Node = add_child_autofree(Node.new())

	var target := _create_screen()
	var pusher := _create_pusher(target, [&"test_push"], [], host)
	assert_push_warning("No screen manager found")

	# When: The pusher is moved under the manager.
	host.remove_child(pusher)
	_manager.add_child(pusher)

	# Then: The pusher wired itself up.
	assert_same(pusher.manager, _manager)
	assert_eq(target.entering.get_connections().size(), 1)

	# When: The push action is simulated.
	_simulate_action(pusher, &"test_push")
	await wait_idle_frames(1)

	# Then: The target screen was pushed.
	assert_eq(_manager.get_depth(), 2)
	assert_eq(_manager.get_current_screen(), target)


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


func after_each() -> void:
	if _test_pusher_scene:
		_test_pusher_scene.take_over_path("")
		_test_pusher_scene = null

	if _test_screen:
		_test_screen.take_over_path("")
		_test_screen = null


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


func _create_pusher_scene(screen: StdScreen) -> String:
	# NOTE: Register the screen under a resource path so that packing the pusher stores
	# a reference to it, rather than a copy of the resource.
	screen.take_over_path(_TEST_SCREEN_PATH)
	_test_screen = screen

	var pusher := Pusher.new()
	pusher.screen = screen
	pusher.push_actions = [&"test_toggle"]
	pusher.pop_actions = [&"test_toggle"]

	_test_pusher_scene = PackedScene.new()
	_test_pusher_scene.pack(pusher)
	pusher.free()

	_test_pusher_scene.take_over_path(_TEST_PUSHER_SCENE_PATH)

	return _TEST_PUSHER_SCENE_PATH


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
	parent: Node = null,
) -> Pusher:
	var pusher := Pusher.new()
	pusher.screen = screen
	pusher.push_actions = p_push_actions
	pusher.pop_actions = p_pop_actions

	# NOTE: Free the pusher with the test, as it may outlive the node it's added to.
	autofree(pusher)

	# Default to a child of the manager, so that the ancestor walk finds it.
	if parent == null:
		parent = _manager

	parent.add_child(pusher)

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
