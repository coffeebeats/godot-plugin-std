##
## std/test/screen_manager_test.gd
##
## Tests pertaining to `StdTestScreenManager`, a manager for a scene under test.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _ATTACHMENT_PATH := "res://test/_test_screen_attachment.tscn"
const _SCENE_PATH := "res://test/_test_screen_scene.tscn"


## _CallbackScene calls `on_ready` when it's ready, as a scene acting on the stack does.
class _CallbackScene:
	extends Control

	var on_ready := Callable()

	func _ready() -> void:
		on_ready.call()


## _DelayedTransition mounts at once and finishes a moment later.
class _DelayedTransition:
	extends StdTransition

	func _enter(context: StdTransitionContext) -> void:
		context.mount()
		context.create_tween().tween_callback(context.done).set_delay(0.05)


## _LateMountTransition mounts a moment later and never finishes.
class _LateMountTransition:
	extends StdTransition

	func _enter(context: StdTransitionContext) -> void:
		context.create_tween().tween_callback(context.mount).set_delay(0.01)


## _PausingScene pauses the tree when it's ready, as a pause menu does.
class _PausingScene:
	extends Control

	func _ready() -> void:
		get_tree().paused = true


## _UnfinishedTransition mounts at once and never finishes.
class _UnfinishedTransition:
	extends StdTransition

	func _enter(context: StdTransitionContext) -> void:
		context.mount()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor: StdInputCursor = null

## _packed_scenes keeps the registered scenes alive, since the resource cache doesn't.
var _packed_scenes: Array[PackedScene] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_and_wait_with_attachment_mounts_it_beside_scene():
	# Given: A screen declaring an attachment.
	var screen := StdScreen.new()
	screen.attachment_scenes = PackedStringArray([_ATTACHMENT_PATH])

	# When: The screen is pushed.
	var scene := await _add_manager().push_and_wait(screen, Control.new())

	# Then: The attachment shares the scene's overlay.
	assert_not_null(scene.get_parent().get_node_or_null(^"TestAttachment"))


func test_push_and_wait_with_bare_transition_skips_screen_transition():
	# Given: A screen whose enter transition never finishes.
	var screen := StdScreen.new()
	screen.transition = _UnfinishedTransition.new()

	# Given: A manager to push it onto.
	var manager := _add_manager()

	# When: The screen is pushed with a bare transition.
	await manager.push_and_wait(screen, Control.new(), StdTransition.new())

	# Then: The push returned with the screen on top.
	assert_true(manager.is_current(screen))


func test_push_and_wait_with_instance_nests_scene_under_manager():
	# Given: A screen and the scene instance to push with it.
	var instance := Control.new()
	var screen := StdScreen.new()

	# Given: A manager to push them onto.
	var manager := _add_manager()

	# When: A screen is pushed with that instance.
	var scene := await manager.push_and_wait(screen, instance)

	# Then: The scene is the one returned, on top of the stack.
	assert_eq(scene, instance)
	assert_true(manager.is_current(screen))

	# Then: The scene reaches the manager through its ancestors.
	assert_true(manager.is_ancestor_of(scene))


func test_push_and_wait_with_push_interrupted_returns_scene():
	# Given: A manager.
	var manager := _add_manager()

	# Given: A screen whose enter transition never finishes.
	var screen := StdScreen.new()
	screen.transition = _UnfinishedTransition.new()

	# Given: Another screen pushed during that transition, which interrupts it.
	var other := StdScreen.new()
	screen.entering.connect(
		func(_scene: Node) -> void: manager.push.call_deferred(other, Control.new())
	)

	# When: The screen is pushed with a scene instance.
	var instance := Control.new()
	var scene := await manager.push_and_wait(screen, instance)

	# Then: The scene is returned, under the screen that interrupted it.
	assert_eq(scene, instance)
	assert_true(manager.is_current(other))


func test_push_and_wait_with_push_waiting_ahead_returns_new_scene():
	# Given: A manager.
	var manager := _add_manager()

	# Given: A scene which pushes a screen when it's ready.
	var opener := _CallbackScene.new()
	opener.on_ready = func() -> void: manager.push(StdScreen.new(), Control.new())

	# Given: That scene already pushed, leaving its push waiting for the next frame.
	manager.push(StdScreen.new(), opener)

	# Given: Another screen and the scene instance to push with it.
	var instance := Control.new()
	var screen := StdScreen.new()

	# When: That screen is pushed in the same frame.
	var scene := await manager.push_and_wait(screen, instance)

	# Then: The second scene is the one returned, on top of the stack.
	assert_eq(scene, instance)
	assert_true(manager.is_current(screen))


func test_push_and_wait_with_scene_leaving_during_transition_returns_null():
	# Given: A manager.
	var manager := _add_manager()

	# Given: A scene which replaces its own screen when it's ready.
	var next := StdScreen.new()
	var instance := _CallbackScene.new()
	instance.on_ready = func() -> void: manager.replace(next, Control.new())

	# Given: A screen whose enter transition is still running at that point.
	var screen := StdScreen.new()
	screen.transition = _LateMountTransition.new()

	# When: The screen is pushed with that scene.
	var scene := await manager.push_and_wait(screen, instance)

	# Then: The scene has left, with its replacement on top of the stack.
	assert_null(scene)
	assert_true(manager.is_current(next))


func test_push_and_wait_with_scene_on_top_returns_new_scene():
	# Given: A manager with a screen on it.
	var manager := _add_manager()
	await manager.push_and_wait(StdScreen.new(), Control.new())

	# Given: A second screen and the scene instance to push with it.
	var instance := Control.new()
	var screen := StdScreen.new()

	# When: That screen is pushed.
	var scene := await manager.push_and_wait(screen, instance)

	# Then: The second scene is the one returned, on top of the stack.
	assert_eq(scene, instance)
	assert_true(manager.is_current(screen))


func test_push_and_wait_with_scene_path_instantiates_scene():
	# Given: A screen naming a scene file.
	var screen := StdScreen.new()
	screen.scene_path = _SCENE_PATH

	# When: The screen is pushed.
	var scene := await _add_manager().push_and_wait(screen)

	# Then: The returned scene is an instance of that file.
	assert_eq(scene.name, &"TestScene")


func test_push_and_wait_with_scene_pausing_tree_still_returns():
	# Given: A scene which pauses the tree when it's ready.
	var instance := _PausingScene.new()

	# When: A screen is pushed with that scene.
	var scene := await _add_manager().push_and_wait(StdScreen.new(), instance)

	# Then: The push returned while the tree was paused.
	assert_true(get_tree().paused)
	assert_eq(scene, instance)


func test_push_and_wait_with_scene_pushing_screen_waits_for_that_push():
	# Given: A manager.
	var manager := _add_manager()

	# Given: A screen whose enter transition finishes a moment later.
	var dialog := StdScreen.new()
	dialog.transition = _DelayedTransition.new()

	# Given: A scene which pushes that screen when it's ready.
	var instance := _CallbackScene.new()
	instance.on_ready = func() -> void: manager.push(dialog, Control.new())

	# When: A screen is pushed with that scene.
	var scene := await manager.push_and_wait(StdScreen.new(), instance)

	# Then: The scene is returned, with the screen it pushed on top.
	assert_eq(scene, instance)
	assert_true(manager.is_current(dialog))


func test_push_and_wait_with_scene_replacing_itself_returns_null():
	# Given: A manager.
	var manager := _add_manager()

	# Given: A screen whose scene replaces it once entered, as a splash does.
	var next := StdScreen.new()
	var screen := StdScreen.new()
	screen.entered.connect(
		func(_scene: Node) -> void: manager.replace(next, Control.new())
	)

	# When: The screen is pushed.
	var scene := await manager.push_and_wait(screen, Control.new())

	# Then: The scene has left, with its replacement on top of the stack.
	assert_null(scene)
	assert_true(manager.is_current(next))


func test_push_and_wait_with_screen_on_stack_returns_its_scene():
	# Given: A manager with a screen on it.
	var manager := _add_manager()
	var screen := StdScreen.new()
	var instance := Control.new()
	await manager.push_and_wait(screen, instance)

	# When: The same screen is pushed again.
	var scene := await manager.push_and_wait(screen)

	# Then: The scene already on the stack is returned.
	assert_eq(scene, instance)
	assert_eq(manager.get_depth(), 2)


func test_push_and_wait_with_screen_transition_waits_for_it():
	# Given: A screen whose enter transition takes time.
	var screen := StdScreen.new()
	screen.transition = _DelayedTransition.new()

	# Given: A record of the screen's enter transition finishing.
	var entered: Array[Node] = []
	screen.entered.connect(entered.append)

	# When: The screen is pushed.
	var scene := await _add_manager().push_and_wait(screen, Control.new())

	# Then: The transition had finished by the time the push returned.
	assert_eq(entered, [scene] as Array[Node])


func test_scene_clicks_through_pushed_dialog_and_back():
	# Given: A manager mounted to take real input.
	var manager := StdTestScreenManager.new()
	var input := await StdTestInput.mount(self, manager)

	# Given: A pushed scene with a button.
	var button := _create_button()
	var scene := Control.new()
	scene.add_child(button)
	var screen := StdScreen.new()
	await manager.push_and_wait(screen, scene)

	# Given: A dialog with a button at the same place, opened by the scene's button.
	var dialog_button := _create_button()
	var dialog := Control.new()
	dialog.add_child(dialog_button)
	var dialog_screen := StdScreen.new()
	button.pressed.connect(func() -> void: manager.push(dialog_screen, dialog))
	dialog_button.pressed.connect(func() -> void: manager.pop())

	# Given: A record of the scene being covered and uncovered.
	var events: Array[StringName] = []
	screen.covered.connect(func(_scene: Node) -> void: events.append(&"covered"))
	screen.uncovered.connect(func(_scene: Node) -> void: events.append(&"uncovered"))

	# When: The scene's button is clicked.
	input.click(button)
	await wait_idle_frames(1)

	# Then: The dialog covers the scene.
	assert_true(manager.is_current(dialog_screen))
	assert_eq(events, [&"covered"] as Array[StringName])

	# When: The dialog's button, over the scene's, is clicked.
	input.click(dialog_button)
	await wait_idle_frames(1)

	# Then: The dialog took the click and closed, uncovering the scene.
	assert_true(manager.is_current(screen))
	assert_eq(events, [&"covered", &"uncovered"] as Array[StringName])


func test_scene_pops_to_empty_base_screen():
	# Given: A pushed screen.
	var manager := _add_manager()
	var screen := StdScreen.new()
	await manager.push_and_wait(screen, Control.new())

	# Given: A record of the result the screen is popped with.
	var results: Array = []
	screen.popped.connect(results.append)

	# When: The scene pops its screen.
	manager.pop(&"result")
	await wait_idle_frames(1)

	# Then: The screen below takes over.
	assert_false(manager.is_current(screen))
	assert_eq(manager.get_depth(), 1)

	# Then: The result arrives.
	assert_eq(results, [&"result"])


func test_scene_regains_focus_after_dialog_closes():
	# Given: A manager mounted to take real input.
	var manager := StdTestScreenManager.new()
	var input := await StdTestInput.mount(self, manager)

	# Given: A pushed scene with a button.
	var button := _create_button()
	var scene := Control.new()
	scene.add_child(button)
	await manager.push_and_wait(StdScreen.new(), scene)

	# Given: The button opens a dialog.
	button.pressed.connect(func() -> void: manager.push(StdScreen.new(), Control.new()))

	# Given: The player navigates by focus, with that button focused.
	_cursor.hide_cursor()
	button.grab_focus()

	# Given: The player has opened the dialog from that button.
	input.press_action(&"ui_accept")
	input.release_action(&"ui_accept")
	await wait_idle_frames(1)
	assert_eq(manager.get_depth(), 3)

	# When: The dialog closes.
	manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is back on the button.
	assert_eq(get_viewport().gui_get_focus_owner(), button)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	get_tree().paused = false


func before_all():
	_register_scene(_ATTACHMENT_PATH, Node.new(), &"TestAttachment")
	_register_scene(_SCENE_PATH, Control.new(), &"TestScene")


func before_each():
	_cursor = StdInputCursor.new()
	add_child_autofree(_cursor)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_manager adds a manager to the tree, without anything sending it input.
func _add_manager() -> StdTestScreenManager:
	var manager := StdTestScreenManager.new()
	add_child_autofree(manager)

	return manager


func _create_button() -> Button:
	var button := Button.new()
	button.size = Vector2(100, 40)

	return button


## _register_scene makes `path` load a packed copy of `node`, which this frees.
func _register_scene(path: String, node: Node, node_name: StringName) -> void:
	node.name = node_name

	var packed := PackedScene.new()
	packed.pack(node)
	node.free()

	packed.take_over_path(path)
	_packed_scenes.append(packed)
