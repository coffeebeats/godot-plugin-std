##
## std/transition/context_test.gd
##
## Tests pertaining to the 'StdTransitionContext' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TransitionTests := preload("transition_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name


## _StopsOnExit stops a transition as it leaves the tree, along with its parent.
class _StopsOnExit:
	extends Node

	var tx: StdTransition = null

	func _exit_tree() -> void:
		tx.stop()


## _UnhandledRecorder records each mouse press that no control took.
class _UnhandledRecorder:
	extends Node

	var presses: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.is_pressed():
			presses += 1


# -- INITIALIZATION ------------------------------------------------------------------ #

var _button: Button = null
var _panel: Control = null
var _recorder: _UnhandledRecorder = null
var _root: Control = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_block_input_with_click_outside_rect_leaves_click_unhandled():
	# Given: A panel entering with a transition that blocks input.
	var input := await StdTestInput.mount(self, _root)
	_enter_held(_create_context(_panel))

	# When: The mouse clicks beside the panel.
	input.click_at(_panel.get_global_rect().end + Vector2(50, 50))

	# Then: Nothing took the click.
	assert_eq(_recorder.presses, 1)


func test_block_input_with_click_inside_rect_takes_click():
	# Given: A panel entering with a transition that blocks input.
	var input := await StdTestInput.mount(self, _root)
	watch_signals(_button)
	_enter_held(_create_context(_panel))

	# When: The mouse clicks the button inside the panel.
	input.click(_button)

	# Then: The button isn't pressed.
	assert_signal_not_emitted(_button, "pressed")

	# Then: The click isn't left for the world.
	assert_eq(_recorder.presses, 0)


func test_block_input_with_hidden_entering_takes_nothing_until_mounted():
	# Given: A hidden panel entering with a transition that hasn't mounted it.
	var input := await StdTestInput.mount(self, _root)
	_panel.hide()
	var tx := _enter_held(_create_context(_panel))

	# When: The mouse clicks where the panel will show.
	input.click(_panel)

	# Then: Nothing took the click.
	assert_eq(_recorder.presses, 1)

	# When: The transition mounts the panel.
	tx.do_mount()

	# When: The mouse clicks there again.
	input.click(_panel)

	# Then: The blocker took the click.
	assert_eq(_recorder.presses, 1)


func test_block_input_when_done_removes_blocker():
	# Given: A panel entering with a transition that blocks input.
	var input := await StdTestInput.mount(self, _root)
	watch_signals(_button)
	var tx := _enter_held(_create_context(_panel))
	var blocker := _find_blocker(_panel)
	assert_not_null(blocker)

	# When: The transition completes.
	tx.complete()

	# Then: The blocker has left the panel.
	assert_null(_find_blocker(_panel))

	# When: The mouse clicks the button.
	input.click(_button)

	# Then: The button is pressed.
	assert_signal_emit_count(_button, "pressed", 1)


func test_block_input_with_transition_opting_out_adds_no_blocker():
	# Given: A transition that doesn't block input.
	await StdTestInput.mount(self, _root)
	var tx := MockTransition.new()
	tx.block_input = false

	# When: A panel enters through it.
	tx.enter(_create_context(_panel))

	# Then: Nothing covers the panel.
	assert_null(_find_blocker(_panel))


func test_block_input_under_containers_is_not_laid_out():
	# Given: A panel that is a container, inside another container.
	var outer := HBoxContainer.new()
	outer.size = Vector2(400, 200)
	_root.add_child(outer)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(200, 100)
	outer.add_child(panel)

	var label := Label.new()
	label.text = "Label"
	panel.add_child(label)

	await StdTestInput.mount(self, _root)

	# When: The panel enters with a blocker.
	_enter_held(_create_context(panel))
	var rect_label := label.get_global_rect()

	# When: Both containers sort.
	outer.queue_sort()
	panel.queue_sort()
	await wait_process_frames(2)

	# Then: The blocker covers the panel.
	assert_eq(_find_blocker(panel).get_global_rect(), panel.get_global_rect())

	# Then: The panel's own content kept its place.
	assert_eq(label.get_global_rect(), rect_label)

	# Then: The blocker isn't among the panel's listed children.
	assert_eq(panel.get_child_count(), 1)


func test_block_input_when_panel_slides_stays_over_panel():
	# Given: A panel entering with a blocker.
	await StdTestInput.mount(self, _root)
	_enter_held(_create_context(_panel))

	# When: The panel moves and resizes.
	_panel.position += Vector2(50, 25)
	_panel.size += Vector2(20, 10)

	# Then: The blocker follows it.
	assert_eq(_find_blocker(_panel).get_global_rect(), _panel.get_global_rect())


func test_block_input_when_control_laid_out_after_mount_refits():
	# Given: A hidden panel in a container, which skips it while it's hidden.
	var outer := VBoxContainer.new()
	outer.size = Vector2(400, 200)
	_root.add_child(outer)

	var panel := Control.new()
	panel.custom_minimum_size = Vector2(200, 100)
	panel.hide()
	outer.add_child(panel)

	await StdTestInput.mount(self, _root)

	var tx := _enter_held(_create_context(panel))

	# When: The transition shows the panel and the container sorts.
	tx.do_mount()
	await wait_process_frames(2)

	# Then: The blocker matches the panel's laid out rect.
	assert_eq(panel.size.x, 400.0)
	assert_eq(_find_blocker(panel).get_global_rect(), panel.get_global_rect())


func test_block_input_when_panel_freed_leaves_context_usable():
	# Given: A panel entering with a blocker.
	await StdTestInput.mount(self, _root)
	var ctx := _create_context(_panel)
	var tx := _enter_held(ctx)

	# When: The panel is freed before the transition completes.
	_root.remove_child(_panel)
	_panel.free()
	tx.complete()

	# Then: The context finished without touching the freed blocker.
	assert_true(ctx._did_finish)


func test_block_input_when_stopped_while_control_leaves_tree_releases_safely():
	# Given: A panel with a blocker, and a sibling that stops the transition on exit.
	await StdTestInput.mount(self, _root)
	var stopper := _StopsOnExit.new()
	stopper.tx = _enter_held(_create_context(_panel))
	_panel.add_child(stopper)

	# When: The panel leaves the tree.
	_root.remove_child(_panel)

	# Then: The blocker is on its way out.
	assert_null(_find_blocker(_panel))

	# Then: Nothing refused the release.
	assert_engine_error_count(0)

	autofree(_panel)


func test_block_input_when_control_reenters_tree_stays_connected_once():
	# Given: A panel with a blocker.
	await StdTestInput.mount(self, _root)
	_enter_held(_create_context(_panel))

	# When: The panel leaves the tree and returns.
	_root.remove_child(_panel)
	_root.add_child(_panel)

	# Then: Nothing connected twice.
	assert_engine_error_count(0)

	# When: The panel moves.
	_panel.position += Vector2(50, 25)

	# Then: The blocker still follows it.
	assert_eq(_find_blocker(_panel).get_global_rect(), _panel.get_global_rect())


func test_abort_removes_blocker_and_suppresses_finished():
	# Given: A panel entering with a blocker.
	await StdTestInput.mount(self, _root)
	var ctx := _create_context(_panel)
	watch_signals(ctx)
	_enter_held(ctx)

	# When: The context is aborted.
	ctx.abort()

	# When: The context is then told it's done.
	ctx.done()

	# Then: The blocker has left the panel.
	assert_null(_find_blocker(_panel))

	# Then: Completion is never reported.
	assert_signal_not_emitted(ctx, "finished")


func test_create_tween_with_paused_host_waits_until_unpaused():
	# Given: A context whose host can't process.
	await StdTestInput.mount(self, _root)
	var ctx := StdTransitionContext.new(_panel)
	_panel.process_mode = Node.PROCESS_MODE_DISABLED

	# Given: A tween from that context.
	var did_run := [false]
	var tween := ctx.create_tween()
	tween.tween_interval(0.01)
	tween.tween_callback(func() -> void: did_run[0] = true)

	# When: Longer than the tween's duration passes.
	await wait_seconds(0.05)

	# Then: The tween hasn't run.
	assert_false(did_run[0])

	# When: The host can process again.
	_panel.process_mode = Node.PROCESS_MODE_INHERIT
	await wait_seconds(0.05)

	# Then: The tween has run.
	assert_true(did_run[0])


func test_create_tween_with_paused_ancestor_waits():
	# Given: A context whose host inherits a disabled process mode.
	await StdTestInput.mount(self, _root)
	var ctx := StdTransitionContext.new(_button)
	_panel.process_mode = Node.PROCESS_MODE_DISABLED

	# Given: A tween from that context.
	var did_run := [false]
	var tween := ctx.create_tween()
	tween.tween_interval(0.01)
	tween.tween_callback(func() -> void: did_run[0] = true)

	# When: Longer than the tween's duration passes.
	await wait_seconds(0.05)

	# Then: The tween hasn't run.
	assert_false(did_run[0])


func test_create_tween_when_host_freed_kills_tween():
	# Given: A tween bound to a host.
	await StdTestInput.mount(self, _root)
	var ctx := StdTransitionContext.new(_panel)
	var tween := ctx.create_tween()
	tween.tween_interval(10.0)

	# When: The host is freed.
	_root.remove_child(_panel)
	_panel.free()
	await wait_process_frames(1)

	# Then: The tween has been killed.
	assert_false(tween.is_valid())


func test_mount_shows_entering_once():
	# Given: A hidden panel entering.
	await StdTestInput.mount(self, _root)
	_panel.hide()
	var ctx := StdTransitionContext.new(_panel)
	ctx.entering = _panel

	# When: The context mounts.
	ctx.mount()

	# Then: The panel shows.
	assert_true(_panel.visible)

	# Given: The panel is hidden again.
	_panel.hide()

	# When: The context mounts again.
	ctx.mount()

	# Then: The second mount did nothing.
	assert_false(_panel.visible)


func test_unmount_hides_exiting_once():
	# Given: A panel exiting.
	await StdTestInput.mount(self, _root)
	var ctx := StdTransitionContext.new(_panel)
	ctx.exiting = _panel

	# When: The context unmounts.
	ctx.unmount()

	# Then: The panel is hidden.
	assert_false(_panel.visible)

	# Given: The panel is shown again.
	_panel.show()

	# When: The context unmounts again.
	ctx.unmount()

	# Then: The second unmount did nothing.
	assert_true(_panel.visible)


func test_swap_hides_exiting_and_shows_entering():
	# Given: A shown panel exiting and a hidden control entering.
	await StdTestInput.mount(self, _root)
	var other := Control.new()
	other.hide()
	_root.add_child(other)

	var ctx := StdTransitionContext.new(_root)
	ctx.entering = other
	ctx.exiting = _panel

	# When: The context swaps them.
	ctx.swap()

	# Then: The entering control shows.
	assert_true(other.visible)

	# Then: The exiting control is hidden.
	assert_false(_panel.visible)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = Control.new()
	_panel.position = Vector2(100, 100)
	_panel.size = Vector2(200, 100)
	_root.add_child(_panel)

	_button = Button.new()
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_button)

	_recorder = _UnhandledRecorder.new()
	_root.add_child(_recorder)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_context(node: Control) -> StdTransitionContext:
	var ctx := StdTransitionContext.new(node)
	ctx.entering = node
	return ctx


## _enter_held starts a blocking transition which stays open until `complete` is called
## on the returned transition.
func _enter_held(ctx: StdTransitionContext) -> MockTransition:
	var tx := MockTransition.new()
	tx.enter(ctx)
	return tx


## _find_blocker returns the blocker on `node`, which is internal and so not listed.
func _find_blocker(node: Node) -> Control:
	for child: Node in node.get_children(true):
		if (
			child.name == &"TransitionInputBlocker"
			and not child.is_queued_for_deletion()
		):
			return child

	return null
