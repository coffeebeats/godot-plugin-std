##
## screen/operation/replace_test.gd
##
## Tests pertaining to the replace screen operation.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Manager := preload("../manager/manager.gd")
const TransitionTests := preload("../transition_test.gd")
const Overlay := preload("../overlay.gd")
const Screen := preload("../screen.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


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


func test_replace_emits_lifecycle_in_correct_order():
	# Given: A manager with one screen.
	var old_screen := _create_screen()
	await _do_push(old_screen)
	var order: Array[String] = []
	_manager.screen_exiting.connect(
		func(_s, _sc): order.append("exiting"),
	)
	_manager.screen_exited.connect(
		func(_s, _sc): order.append("exited"),
	)
	_manager.screen_entering.connect(
		func(_s, _sc): order.append("entering"),
	)
	_manager.screen_entered.connect(
		func(_s, _sc): order.append("entered"),
	)
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


func test_replace_duplicate_non_self_rejected():
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


func test_replace_self_supported_with_overlay_reuse():
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


func test_replace_transfers_overlay_when_both_block():
	# Given: Two blocking screens on the stack.
	var first := _create_screen()
	var first_scene := Control.new()
	await _do_push(first, first_scene)
	var second := _create_screen()
	var second_scene := Control.new()
	await _do_push(second, second_scene)
	var overlay := second_scene.get_parent() as Overlay

	# When: The top is replaced with another blocking screen.
	var replacement := _create_screen()
	var replacement_scene := Control.new()
	_manager.replace(replacement, replacement_scene)
	await wait_idle_frames(1)

	# Then: The replacement reuses the same overlay.
	assert_not_freed(overlay, "transferred overlay")
	assert_same(replacement_scene.get_parent(), overlay)


func test_replace_no_overlay_transfer_when_non_blocking():
	# Given: A non-blocking screen on the stack.
	var first := _create_screen()
	var first_scene := Control.new()
	await _do_push(first, first_scene)
	var nb := _create_screen(null, false)
	var nb_scene := Control.new()
	await _do_push(nb, nb_scene)

	# When: The non-blocking screen is replaced with a blocking one.
	var replacement := _create_screen()
	var replacement_scene := Control.new()
	_manager.replace(replacement, replacement_scene)
	await wait_idle_frames(1)

	# Then: The replacement gets a new overlay (no transfer from
	# non-blocking).
	assert_ne(
		first_scene.get_parent(),
		replacement_scene.get_parent(),
	)


func test_replace_with_transition_delays_entered():
	# Given: A screen on the stack.
	var original := _create_screen()
	await _do_push(original)
	watch_signals(_manager)

	# When: The top is replaced with a transitioning screen.
	(
		_manager
		. replace(
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


func test_replace_with_transition_blocks_input():
	# Given: A screen on the stack.
	await _do_push()

	# When: The top is replaced with a transitioning, blocking screen.
	var transition := MockTransition.new()
	transition.block_input = true
	(
		_manager
		. replace(
			_create_screen(transition),
			Control.new(),
		)
	)
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.replace_started)

	# Then: An input blocker is present.
	var blocker := (
		_manager
		. get_node_or_null(
			"TransitionInputBlocker",
		)
	)
	assert_not_null(blocker)

	# When: The transition completes.
	active.do_swap()
	active.complete()
	await wait_idle_frames(1)

	# Then: The input blocker is removed from the tree.
	assert_false(blocker.is_inside_tree())


func test_replace_emits_popped_null_on_old_screen():
	# Given: A manager with one screen.
	var old_screen := _create_screen()
	await _do_push(old_screen)

	var received: Array = []
	old_screen.popped.connect(func(r): received.append(r))

	# When: The top is replaced.
	_manager.replace(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: The old screen received popped(null).
	assert_eq(received.size(), 1)
	assert_eq(received[0], null)


func test_replace_discards_previous_screen_with_missing_scene():
	# Given: Two screens; the top screen's scene is missing.
	var first := _create_screen()
	await _do_push(first)
	var second := _create_screen()
	await _do_push(second)

	var received: Array = []
	second.popped.connect(func(r): received.append(r))
	watch_signals(_manager)

	# When: The top screen's scene is erased and a replace is attempted.
	_manager._scenes.erase(second)
	_manager.replace(_create_screen())
	await wait_idle_frames(1)

	# Then: The expected error was logged.
	assert_push_error("Discarding screen with missing scene.")

	# Then: The broken screen was removed.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), first)

	# Then: The popped signal was emitted with null.
	assert_eq(received, [null])

	# Then: The replacement was not pushed.
	assert_signal_not_emitted(_manager, "screen_entered")


func test_replace_discards_previous_screen_frees_owned_overlay():
	# Given: Two blocking screens with separate overlays.
	var first := _create_screen()
	var first_scene := Control.new()
	await _do_push(first, first_scene)
	var second := _create_screen()
	var second_scene := Control.new()
	await _do_push(second, second_scene)
	var overlay := second_scene.get_parent() as Overlay

	# When: The top screen's scene is erased and a replace is attempted.
	_manager._scenes.erase(second)
	_manager.replace(_create_screen())
	await wait_idle_frames(1)

	# Then: The expected error was logged.
	assert_push_error("Discarding screen with missing scene.")

	# Then: The owned overlay was freed.
	assert_freed(overlay, "overlay for discarded screen")


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
