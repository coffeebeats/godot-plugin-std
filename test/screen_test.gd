##
## std/test/screen_test.gd
##
## Tests pertaining to `StdTestScreen`, which mounts a screen under a manager.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _ATTACHMENT_PATH := "res://test/_test_screen_attachment.tscn"
const _SCENE_PATH := "res://test/_test_screen_scene.tscn"


## _DelayedTransition mounts at once and finishes a moment later.
class _DelayedTransition:
	extends StdScreenTransition

	func _push(context: StdScreenTransitionContext) -> void:
		context.mount()
		context.create_tween().tween_callback(context.done).set_delay(0.05)


## _PausingScene pauses the tree when it's ready, as a pause menu does.
class _PausingScene:
	extends Control

	func _ready() -> void:
		get_tree().paused = true


## _UnfinishedTransition mounts at once and never finishes.
class _UnfinishedTransition:
	extends StdScreenTransition

	func _push(context: StdScreenTransitionContext) -> void:
		context.mount()


# -- INITIALIZATION ------------------------------------------------------------------ #

## _packed_scenes keeps the registered scenes alive, since the resource cache doesn't.
var _packed_scenes: Array[PackedScene] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_mount_with_attachment_mounts_it_beside_scene():
	# Given: A screen declaring an attachment.
	var screen := StdScreen.new()
	screen.attachment_scenes = PackedStringArray([_ATTACHMENT_PATH])

	# When: The screen is mounted.
	var mounted := await StdTestScreen.mount(self, screen, Control.new())

	# Then: The attachment shares the scene's overlay.
	assert_not_null(mounted.scene.get_parent().get_node_or_null(^"TestAttachment"))


func test_mount_with_cursor_in_tree_keeps_it():
	# Given: A cursor already in the tree, as a game's input scene adds.
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	# When: A screen is mounted.
	await StdTestScreen.mount(self, StdScreen.new(), Control.new())

	# Then: That cursor is still the only one.
	var cursor_group := StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR)
	assert_eq(cursor_group.list_members(), [cursor])


func test_mount_with_instance_nests_scene_under_manager():
	# Given: A scene instance.
	var scene := Control.new()
	var screen := StdScreen.new()

	# When: A screen is mounted with that instance.
	var mounted := await StdTestScreen.mount(self, screen, scene)

	# Then: The scene is the one returned, on top of the stack.
	assert_eq(mounted.scene, scene)
	assert_true(mounted.manager.is_current(screen))

	# Then: The scene reaches the manager through its ancestors.
	assert_true(mounted.manager.is_ancestor_of(scene))


func test_mount_with_scene_path_instantiates_scene():
	# Given: A screen naming a scene file.
	var screen := StdScreen.new()
	screen.scene_path = _SCENE_PATH

	# When: The screen is mounted.
	var mounted := await StdTestScreen.mount(self, screen)

	# Then: The returned scene is an instance of that file.
	assert_eq(mounted.scene.name, &"TestScene")


func test_mount_with_scene_pausing_tree_still_returns():
	# Given: A scene which pauses the tree when it's ready.
	var scene := _PausingScene.new()

	# When: A screen is mounted with that scene.
	var mounted := await StdTestScreen.mount(self, StdScreen.new(), scene)

	# Then: The mount returned while the tree was paused.
	assert_true(get_tree().paused)
	assert_eq(mounted.scene, scene)


func test_mount_with_screen_transition_waits_for_it():
	# Given: A screen whose enter transition takes time.
	var screen := StdScreen.new()
	screen.transition = _DelayedTransition.new()

	# Given: A record of the screen's enter transition finishing.
	var entered: Array[Node] = []
	screen.entered.connect(entered.append)

	# When: The screen is mounted.
	var mounted := await StdTestScreen.mount(self, screen, Control.new())

	# Then: The transition had finished by the time the mount returned.
	assert_eq(entered, [mounted.scene] as Array[Node])


func test_mount_with_bare_transition_skips_screen_transition():
	# Given: A screen whose enter transition never finishes.
	var screen := StdScreen.new()
	screen.transition = _UnfinishedTransition.new()

	# When: The screen is mounted with a bare transition.
	var transition := StdScreenTransition.new()
	var mounted := await StdTestScreen.mount(self, screen, Control.new(), transition)

	# Then: The mount returned with the screen entered.
	assert_true(mounted.manager.is_current(screen))


func test_mounted_scene_pops_to_empty_base_screen():
	# Given: A mounted screen.
	var screen := StdScreen.new()
	var mounted := await StdTestScreen.mount(self, screen, Control.new())

	# Given: A record of the result the screen is popped with.
	var results: Array = []
	screen.popped.connect(results.append)

	# When: The scene pops its screen.
	mounted.manager.pop(&"result")
	await wait_idle_frames(1)

	# Then: The screen below takes over, and the result arrives.
	assert_false(mounted.manager.is_current(screen))
	assert_eq(mounted.manager.get_depth(), 1)
	assert_eq(results, [&"result"])


func test_mounted_scene_clicks_through_pushed_dialog_and_back():
	# Given: A mounted scene with a button.
	var button := _create_button()
	var scene := Control.new()
	scene.add_child(button)
	var screen := StdScreen.new()
	var mounted := await StdTestScreen.mount(self, screen, scene)

	# Given: A dialog with a button at the same place, opened by the scene's button.
	var dialog_button := _create_button()
	var dialog := Control.new()
	dialog.add_child(dialog_button)
	var dialog_screen := StdScreen.new()
	button.pressed.connect(func() -> void: mounted.manager.push(dialog_screen, dialog))
	dialog_button.pressed.connect(func() -> void: mounted.manager.pop())

	# Given: A record of the scene being covered and uncovered.
	var events: Array[StringName] = []
	screen.covered.connect(func(_scene: Node) -> void: events.append(&"covered"))
	screen.uncovered.connect(func(_scene: Node) -> void: events.append(&"uncovered"))

	# When: The scene's button is clicked.
	mounted.input.click(button)
	await wait_idle_frames(1)

	# Then: The dialog covers the scene.
	assert_true(mounted.manager.is_current(dialog_screen))
	assert_eq(events, [&"covered"] as Array[StringName])

	# When: The dialog's button, over the scene's, is clicked.
	mounted.input.click(dialog_button)
	await wait_idle_frames(1)

	# Then: The dialog took the click and closed, uncovering the scene.
	assert_true(mounted.manager.is_current(screen))
	assert_eq(events, [&"covered", &"uncovered"] as Array[StringName])


func test_mounted_scene_regains_focus_after_dialog_closes():
	# Given: A mounted scene with a button.
	var button := _create_button()
	var scene := Control.new()
	scene.add_child(button)
	var mounted := await StdTestScreen.mount(self, StdScreen.new(), scene)

	# Given: The button opens a dialog.
	button.pressed.connect(
		func() -> void: mounted.manager.push(StdScreen.new(), Control.new())
	)

	# Given: The player navigates by focus, with that button focused.
	var cursor: StdInputCursor = StdGroup.get_sole_member(
		StdInputCursor.GROUP_INPUT_CURSOR
	)
	cursor.hide_cursor()
	button.grab_focus()

	# Given: The player has opened the dialog from that button.
	mounted.input.press_action(&"ui_accept")
	mounted.input.release_action(&"ui_accept")
	await wait_idle_frames(1)
	assert_eq(mounted.manager.get_depth(), 3)

	# When: The dialog closes.
	mounted.manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is back on the button.
	assert_eq(get_viewport().gui_get_focus_owner(), button)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	get_tree().paused = false


func before_all():
	_register_scene(_ATTACHMENT_PATH, Node.new(), &"TestAttachment")
	_register_scene(_SCENE_PATH, Control.new(), &"TestScene")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


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
