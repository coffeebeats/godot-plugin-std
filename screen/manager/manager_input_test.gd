##
## screen/manager/manager_input_test.gd
##
## Tests pertaining to how `StdScreenManager` isolates input between overlays, and how
## screen lifecycle notifications reach attachments.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Overlay := preload("../overlay.gd")
const Screen := preload("../screen.gd")
const Manager := preload("manager.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## _InputRecorder stands in for a scene or attachment, recording the test action and the
## screen lifecycle notifications it receives.
class _InputRecorder:
	extends Control

	## sink receives this node's name each time the test action reaches it; ordering
	## tests share one array across recorders.
	var sink: Array = []

	var notifications: Array[int] = []

	func _notification(what: int) -> void:
		if (
			what == StdScreenManager.NOTIFICATION_SCREEN_COVERED
			or what == StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED
		):
			notifications.append(what)

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(_TEST_ACTION):
			sink.append(String(name))


# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_ACTION := &"test_action"
const _TEST_RECORDER_PATH := "res://screen/_test_recorder.tscn"

var _manager: Manager = null
var _test_recorder: PackedScene = null

# -- TEST METHODS -------------------------------------------------------------------- #


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


func test_unhandled_input_visits_children_before_parent_and_stops_at_consumer():
	# Given: Two overlays holding a scene and an attachment each, a node outside both, in
	# the manager's creation order; the top overlay consumes.
	var sink: Array = []
	var holder := Control.new()
	add_child_autofree(holder)

	holder.add_child(_create_recorder(&"Outside", sink))

	var lower := Overlay.new()
	holder.add_child(lower)
	lower.add_child(_create_recorder(&"LowerScene", sink))
	lower.add_child(_create_recorder(&"LowerAttachment", sink))

	var top := Overlay.new()
	holder.add_child(top)
	top.add_child(_create_recorder(&"TopScene", sink))
	top.add_child(_create_recorder(&"TopAttachment", sink))
	top.consumes_unhandled_input = true

	# When: An action is dispatched.
	_dispatch_action()

	# Then: Later siblings ran first, children before parent, nothing below the consumer.
	assert_eq(sink, ["TopAttachment", "TopScene"])


func test_covered_overlay_attachment_receives_no_unhandled_input():
	# Given: A screen with a recording attachment, covered by a second screen.
	var host := _create_screen()
	host.attachment_scenes = PackedStringArray([_TEST_RECORDER_PATH])
	await _do_push(host)
	await _do_push()

	var recorder: _InputRecorder = _get_attachments(host)[0]

	# When: An action is dispatched.
	_dispatch_action()

	# Then: The covered attachment never saw it.
	assert_eq(recorder.sink, [])


func test_pop_restores_unhandled_input_to_uncovered_overlay():
	# Given: A screen with a recording attachment, covered by a second screen.
	var host := _create_screen()
	host.attachment_scenes = PackedStringArray([_TEST_RECORDER_PATH])
	await _do_push(host)
	await _do_push()

	var recorder: _InputRecorder = _get_attachments(host)[0]

	# When: The covering screen is popped and an action is dispatched.
	_manager.pop(null, true)
	await wait_idle_frames(2)
	_dispatch_action()

	# Then: The attachment receives input again.
	assert_eq(recorder.sink, ["TestRecorder"])


func test_middle_overlay_stops_consuming_while_covered_and_resumes_when_top():
	# Given: Three screens, the middle one with a recording attachment.
	await _do_push()

	var middle := _create_screen()
	middle.attachment_scenes = PackedStringArray([_TEST_RECORDER_PATH])
	await _do_push(middle)

	var overlay := _manager._overlays.get_overlay(middle)
	assert_true(overlay.consumes_unhandled_input)

	await _do_push()

	var recorder: _InputRecorder = _get_attachments(middle)[0]

	# Then: The middle overlay no longer consumes and no longer receives.
	assert_false(overlay.consumes_unhandled_input)
	_dispatch_action()
	assert_eq(recorder.sink, [])

	# When: The top screen is popped.
	_manager.pop(null, true)
	await wait_idle_frames(2)

	# Then: The middle overlay consumes and receives again.
	assert_true(overlay.consumes_unhandled_input)
	_dispatch_action()
	assert_eq(recorder.sink, ["TestRecorder"])


func test_shared_overlay_screens_both_receive_unhandled_input():
	# Given: Two screens sharing one overlay, each with a recording scene, above a base.
	await _do_push()

	var lower := _create_recorder(&"Lower")
	await _do_push(_create_screen(), lower)

	var upper := _create_recorder(&"Upper")
	await _do_push(_create_screen(null, false), upper)

	assert_same(lower.get_parent(), upper.get_parent())

	# When: An action is dispatched.
	_dispatch_action()

	# Then: Both scenes in the shared overlay saw it.
	assert_eq(lower.sink, ["Lower"])
	assert_eq(upper.sink, ["Upper"])


func test_single_overlay_does_not_consume_unhandled_input():
	# Given: A node which receives unhandled input only after the manager has, and a
	# single screen in the stack.
	var outside := _create_recorder(&"Outside")
	add_child_autofree(outside)
	move_child(outside, 0)

	await _do_push()

	# When: An action is dispatched.
	_dispatch_action()

	# Then: The lone overlay let it through.
	var overlay := _manager._overlays.get_current(_manager._stack)
	assert_false(overlay.consumes_unhandled_input)
	assert_eq(outside.sink, ["Outside"])


func test_pop_to_single_overlay_stops_consuming_unhandled_input():
	# Given: A node which receives unhandled input only after the manager has, and two
	# screens in the stack.
	var outside := _create_recorder(&"Outside")
	add_child_autofree(outside)
	move_child(outside, 0)

	await _do_push()
	await _do_push()

	# When: The top screen is popped and an action is dispatched.
	_manager.pop(null, true)
	await wait_idle_frames(2)
	_dispatch_action()

	# Then: The remaining lone overlay let it through.
	var overlay := _manager._overlays.get_current(_manager._stack)
	assert_false(overlay.consumes_unhandled_input)
	assert_eq(outside.sink, ["Outside"])


func test_attachment_receives_covered_and_uncovered_notifications():
	# Given: A screen with a recording attachment.
	var host := _create_screen()
	host.attachment_scenes = PackedStringArray([_TEST_RECORDER_PATH])
	await _do_push(host)

	var recorder: _InputRecorder = _get_attachments(host)[0]

	# When: The screen is covered.
	await _do_push()

	# Then: The attachment was notified.
	assert_eq(recorder.notifications, [Manager.NOTIFICATION_SCREEN_COVERED])

	# When: The covering screen is popped.
	_manager.pop(null, true)
	await wait_idle_frames(2)

	# Then: The attachment was notified again.
	assert_eq(
		recorder.notifications,
		[Manager.NOTIFICATION_SCREEN_COVERED, Manager.NOTIFICATION_SCREEN_UNCOVERED],
	)


func test_attachment_receives_unhandled_input_before_scene():
	# Given: A screen whose scene and attachment both record into one array.
	var sink: Array = []
	var scene := _create_recorder(&"Scene", sink)

	var host := _create_screen()
	host.attachment_scenes = PackedStringArray([_TEST_RECORDER_PATH])
	await _do_push(host, scene)

	var recorder: _InputRecorder = _get_attachments(host)[0]
	recorder.sink = sink

	# When: An action is dispatched.
	_dispatch_action()

	# Then: The attachment ran before the scene.
	assert_eq(sink, ["TestRecorder", "Scene"])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(_TEST_ACTION)

	if _test_recorder:
		_test_recorder.take_over_path("")
		_test_recorder = null


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION)

	_test_recorder = PackedScene.new()

	var recorder := _create_recorder(&"TestRecorder")
	_test_recorder.pack(recorder)
	recorder.free()

	_test_recorder.take_over_path(_TEST_RECORDER_PATH)


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_recorder(name: StringName, sink: Array = []) -> _InputRecorder:
	var recorder := _InputRecorder.new()
	recorder.name = name
	recorder.sink = sink
	return recorder


func _create_screen(
	transition: StdScreenTransition = null,
	block_input_below: bool = true,
) -> Screen:
	var screen := Screen.new()
	screen.transition = transition
	screen.block_input_below = block_input_below
	return screen


## _dispatch_action sends the test action through the engine's input handling so that
## ordering and isolation match runtime.
func _dispatch_action() -> void:
	var event := InputEventAction.new()
	event.action = _TEST_ACTION
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


func _get_attachments(screen: Screen) -> Array:
	var nodes: Array = []
	if screen in _manager._attachments:
		nodes = _manager._attachments[screen]

	return nodes
