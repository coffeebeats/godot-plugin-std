# gdlint:disable=max-public-methods
##
## screen/manager/manager_test.gd
##
## Tests pertaining to `StdScreenManager`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Overlay := preload("../overlay.gd")
const Screen := preload("../screen.gd")
const TransitionTests := preload("../transition_test.gd")
const Manager := preload("manager.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_ATTACHMENT_PATH := "res://screen/_test_attachment.tscn"

var _manager: Manager = null
var _sound_player = null
var _test_attachment: PackedScene = null

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

	# When: pop(null, true) is called with force.
	_manager.pop(null, true)
	await wait_idle_frames(1)

	# Then: The screen was popped.
	assert_eq(_manager.get_depth(), 1)


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


func test_focus_restored_on_pop_even_when_focus_mode_cleared_synchronously():
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: A first screen with a focused button.
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(null, first_scene)
	button.grab_focus()
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


func test_focus_restoration_respects_consumer_override_after_pop():
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: A first screen with focusable buttons A and B, focus on A.
	var first := _create_screen()
	var first_scene := Control.new()
	var button_a := Button.new()
	button_a.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button_a)
	var button_b := Button.new()
	button_b.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button_b)
	await _do_push(first, first_scene)
	button_a.grab_focus()
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button_a,
	)

	# Given: A second screen pushed on top.
	var second := _create_screen()
	await _do_push(second)

	# Given: A handler that overrides focus to B when popped.
	second.popped.connect(
		func(_result) -> void: cursor.set_pending_focus(button_b),
	)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is on B (consumer override), not A (saved focus).
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button_b,
	)


func test_focus_restoration_skips_disabled_button_after_pop():
	# Given: Focus mode (cursor hidden) — this is where the bug manifests.
	_get_cursor().hide_cursor()

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

	# Given: A second screen pushed on top.
	var second := _create_screen()
	await _do_push(second)

	# Given: A handler that disables the button when the screen is popped.
	second.popped.connect(
		func(_result) -> void: button.disabled = true,
	)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus does NOT land on the disabled button.
	assert_ne(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_focus_saved_from_hovered_when_cursor_visible():
	# Given: Cursor visible (mouse mode).
	_get_cursor().show_cursor()

	# Given: A first screen with a hoverable button (no focus).
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)

	# Given: The button is hovered (simulated via cursor).
	_get_cursor().set_hovered(button)

	# When: A second screen is pushed (saves hovered as focus).
	await _do_push()

	# When: The cursor is hidden before popping (enter focus mode).
	_get_cursor().hide_cursor()

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button (saved from hovered).
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


func test_push_recalculates_hover_when_cursor_visible():
	# NOTE: SubViewport required; root viewport doesn't
	# dispatch GUI input in headless mode.
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 300)
	add_child_autofree(sv)
	(
		sv
		. notification(
			Viewport.NOTIFICATION_VP_MOUSE_ENTER,
		)
	)

	# Given: A manager inside the SubViewport.
	var sv_manager := Manager.new()
	sv.add_child(sv_manager)
	await wait_idle_frames(1)
	_get_cursor().show_cursor()

	# Given: A base screen and the mouse at a known position.
	sv_manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 20)
	motion.relative = Vector2(50, 20)
	sv.push_input(motion)
	await get_tree().process_frame

	# When: A screen with a hoverable button at the cursor position is pushed.
	var scene := Control.new()
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = Vector2(100, 40)
	scene.add_child(button)
	sv_manager.push(_create_screen(), scene)
	await wait_idle_frames(1)

	# Then: The button is hovered after deferred recalculation.
	assert_true(
		button.is_hovered(),
		"button should be hovered after push",
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


func _get_attachments(screen: Screen) -> Array:
	var nodes: Array = []
	if screen in _manager._attachments:
		nodes = _manager._attachments[screen]

	return nodes


func _get_cursor() -> StdInputCursor:
	return (
		StdGroup
		. get_sole_member(
			StdInputCursor.GROUP_INPUT_CURSOR,
		)
	)
