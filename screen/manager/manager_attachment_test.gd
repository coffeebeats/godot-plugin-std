##
## screen/manager/manager_attachment_test.gd
##
## Tests pertaining to how `StdScreenManager` mounts and frees screen attachments.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Screen := preload("../screen.gd")
const Manager := preload("manager.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_ATTACHMENT_PATH := "res://screen/_test_attachment.tscn"

var _manager: Manager = null
var _test_attachment: PackedScene = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_mounts_attachment_into_overlay():
	# Given: A screen declaring an attachment scene.
	var screen := _create_screen()
	screen.attachment_scenes = PackedStringArray([_TEST_ATTACHMENT_PATH])
	var scene := Control.new()

	# When: The screen is pushed.
	await _do_push(screen, scene)

	# Then: The attachment was mounted alongside the scene in the same overlay.
	var attachments := _get_attachments(screen)
	assert_eq(attachments.size(), 1)

	var overlay := _manager._overlays.get_overlay(screen)
	assert_eq(attachments[0].get_parent(), overlay)
	assert_eq(scene.get_parent(), overlay)

	# Then: The attachment follows the scene, so it receives unhandled input first.
	assert_gt(attachments[0].get_index(), scene.get_index())


func test_pop_frees_attachments():
	# Given: A base screen and a pushed screen with an attachment.
	await _do_push()
	var screen := _create_screen()
	screen.attachment_scenes = PackedStringArray([_TEST_ATTACHMENT_PATH])
	await _do_push(screen)

	var attachment: Node = _get_attachments(screen)[0]

	# When: The screen is popped.
	_manager.pop(null, true)
	await wait_idle_frames(2)

	# Then: The attachment was freed and its record removed.
	assert_false(is_instance_valid(attachment))
	assert_false(screen in _manager._attachments)


func test_pop_defers_attachment_free_until_idle():
	# Given: A base screen and a pushed screen with an attachment.
	await _do_push()
	var screen := _create_screen()
	screen.attachment_scenes = PackedStringArray([_TEST_ATTACHMENT_PATH])
	await _do_push(screen)

	var attachment: Node = _get_attachments(screen)[0]

	# When: The screen is popped, which happens immediately without a transition.
	_manager.pop(null, true)

	# Then: The attachment is queued for deletion, not already deleted.
	assert_true(
		is_instance_valid(attachment),
		"attachment was deleted synchronously during the pop",
	)
	assert_true(attachment.is_queued_for_deletion())

	# When: A frame elapses.
	await wait_idle_frames(2)

	# Then: The attachment is gone.
	assert_false(is_instance_valid(attachment))


func test_pop_defers_scene_free_until_idle():
	# Given: A base screen and a pushed screen which does not cache its scene.
	await _do_push()
	var screen := _create_screen()
	var scene := Control.new()
	await _do_push(screen, scene)

	# When: The screen is popped.
	_manager.pop(null, true)

	# Then: The scene is queued for deletion, not already deleted.
	assert_true(
		is_instance_valid(scene),
		"scene was deleted synchronously during the pop",
	)
	assert_true(scene.is_queued_for_deletion())

	# When: A frame elapses.
	await wait_idle_frames(2)

	# Then: The scene is gone.
	assert_false(is_instance_valid(scene))


func test_pop_frees_attachments_when_scene_is_cached():
	# Given: A pushed screen which caches its scene instance.
	await _do_push()
	var screen := _create_screen()
	screen.cache_instance = true
	screen.attachment_scenes = PackedStringArray([_TEST_ATTACHMENT_PATH])
	var scene := Control.new()
	await _do_push(screen, scene)

	var attachment: Node = _get_attachments(screen)[0]

	# When: The screen is popped.
	_manager.pop(null, true)
	await wait_idle_frames(2)

	# Then: The scene was cached but the attachment was freed.
	assert_eq(_manager._cache.get(screen), scene)
	assert_false(is_instance_valid(attachment))


func test_teardown_frees_attachments():
	# Given: A pushed screen with an attachment.
	var screen := _create_screen()
	screen.attachment_scenes = PackedStringArray([_TEST_ATTACHMENT_PATH])
	await _do_push(screen)

	var attachment: Node = _get_attachments(screen)[0]

	# When: The manager is torn down.
	_manager._teardown()
	await wait_idle_frames(2)

	# Then: The attachment was freed and no records remain.
	assert_false(is_instance_valid(attachment))
	assert_true(_manager._attachments.is_empty())


func test_unavailable_attachment_scene_does_not_block_mount():
	# Given: A pushed screen with an attachment scene which was never loaded.
	var screen := _create_screen()
	await _do_push(screen)
	screen.attachment_scenes = PackedStringArray(["res://screen/_test_missing.tscn"])

	# When: Attachments are mounted for the screen.
	var overlay := _manager._overlays.get_overlay(screen)
	_manager._mount_attachments(screen, overlay)

	# Then: The expected error was logged.
	assert_push_error("Failed to load attachment scene.")

	# Then: Nothing was mounted and the screen is unaffected.
	assert_eq(_get_attachments(screen).size(), 0)
	assert_eq(_manager.get_current_screen(), screen)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	if _test_attachment:
		_test_attachment.take_over_path("")
		_test_attachment = null


func before_all() -> void:
	_test_attachment = PackedScene.new()

	var node := Node.new()
	node.name = &"TestAttachment"
	_test_attachment.pack(node)
	node.free()

	_test_attachment.take_over_path(_TEST_ATTACHMENT_PATH)


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


func _get_attachments(screen: Screen) -> Array:
	var nodes: Array = []
	if screen in _manager._attachments:
		nodes = _manager._attachments[screen]

	return nodes
