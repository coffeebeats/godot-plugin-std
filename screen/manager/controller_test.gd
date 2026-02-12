# gdlint:ignore=max-public-methods

##
## screen/manager/controller_test.gd
##
## Tests pertaining to the transition controller.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Controller := preload("controller.gd")
const Screen := preload("../screen.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class MockManager:
	extends Node

	var overlay: Node = null
	var settled_count: int = 0

	func _get_current_overlay() -> Node:
		return overlay

	func _on_transitions_settled() -> void:
		settled_count += 1


class MockTransition:
	extends "../transition.gd"

	var started := false
	var stopped := false
	var was_reset := false
	var is_entering_arg: bool
	var _ctx: StdScreenTransitionContext

	func _start(
		context: StdScreenTransitionContext,
		_scene: Node,
		is_entering: bool,
	) -> void:
		_ctx = context
		started = true
		is_entering_arg = is_entering

	func _stop() -> void:
		stopped = true

	func _reset() -> void:
		_stop()
		was_reset = true

	## complete triggers transition completion from tests.
	func complete() -> void:
		_ctx.done()


class Spy:
	extends RefCounted

	func called(_tag: String = "") -> void:
		pass


# -- INITIALIZATION ------------------------------------------------------------------ #

var _mock: MockManager = null
var _controller: Controller = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_run_duplicates_transition_resource():
	# Given: A screen with enter and exit transitions.
	var screen := Screen.new()
	var enter_transition := MockTransition.new()
	var exit_transition := MockTransition.new()
	screen.transition_enter = enter_transition
	screen.transition_exit = exit_transition
	screen.block_on_enter = true
	screen.block_on_exit = true

	# When: run_enter is called.
	_controller.run_enter(screen, _create_scene(), Callable())

	# Then: The tracked transition is a duplicate, not the original.
	assert_eq(_controller._active_transitions.size(), 1)
	assert_ne(_controller._active_transitions[0], enter_transition)

	# When: All transitions are stopped, then run_exit is called.
	_controller.stop_all()
	_controller.run_exit(
		screen,
		_create_scene(),
		func() -> void: pass,
		Callable(),
	)

	# Then: The tracked transition is a duplicate, not the original.
	assert_eq(_controller._active_transitions.size(), 1)
	assert_ne(_controller._active_transitions[0], exit_transition)


func test_allow_input_clamps_at_zero():
	# Given: A controller with no active blocks.
	var initial := _mock.settled_count

	# When: allow_input is called without a matching block.
	_controller.allow_input()
	_controller.allow_input()

	# Then: The count does not go negative; settled fires
	# each time.
	assert_eq(_mock.settled_count, initial + 2)


func test_allow_input_enables_overlay_only_at_zero():
	# Given: A controller with two blocks.
	var overlay := _add_overlay()
	_controller.block_input()
	_controller.block_input()

	# When: One block is released.
	_controller.allow_input()

	# Then: The overlay is still disabled (count=1).
	assert_eq(
		overlay.process_mode,
		Node.PROCESS_MODE_DISABLED,
	)

	# When: The second block is released.
	_controller.allow_input()

	# Then: The overlay is re-enabled.
	assert_eq(
		overlay.process_mode,
		Node.PROCESS_MODE_INHERIT,
	)


func test_block_input_disables_overlay_on_first_call():
	# Given: A controller with an overlay.
	var overlay := _add_overlay()

	# When: Input is blocked for the first time.
	_controller.block_input()

	# Then: The overlay is disabled.
	assert_eq(
		overlay.process_mode,
		Node.PROCESS_MODE_DISABLED,
	)


func test_block_input_skips_disable_on_subsequent_calls():
	# Given: Input already blocked once.
	var overlay := _add_overlay()
	_controller.block_input()
	overlay.process_mode = Node.PROCESS_MODE_INHERIT

	# When: Input is blocked again.
	_controller.block_input()

	# Then: The overlay was not re-disabled (count > 1).
	assert_eq(
		overlay.process_mode,
		Node.PROCESS_MODE_INHERIT,
	)


func test_block_input_tolerates_null_overlay():
	# Given: A controller with no overlay.
	_mock.overlay = null

	# When: Input is blocked.
	_controller.block_input()

	# Then: No engine errors are generated.
	assert_engine_error_count(0)


func test_run_enter_blocking_delays_on_complete():
	# Given: A screen with a blocking enter transition.
	var screen := Screen.new()
	screen.transition_enter = MockTransition.new()
	screen.block_on_enter = true
	var spy = double(Spy).new()

	# When: run_enter is called.
	_controller.run_enter(screen, _create_scene(), func(): spy.called())

	# Then: Transition started but callback is deferred.
	var active: MockTransition = _controller._active_transitions[0]
	assert_true(active.started)
	assert_not_called(spy, "called")

	# When: The transition completes.
	active.complete()

	# Then: The callback fires.
	assert_called(spy, "called")


func test_run_enter_immediate_callback_without_transition():
	# Given: A screen with no enter transition.
	var screen := Screen.new()
	var spy = double(Spy).new()

	# When: run_enter is called.
	_controller.run_enter(screen, _create_scene(), func(): spy.called())

	# Then: The callback fires immediately.
	assert_called(spy, "called")


func test_run_enter_nonblocking_completes_immediately():
	# Given: A non-blocking enter transition.
	var screen := Screen.new()
	screen.transition_enter = MockTransition.new()
	var spy = double(Spy).new()

	# When: run_enter is called.
	_controller.run_enter(screen, _create_scene(), func(): spy.called())

	# Then: The callback fires immediately despite the in-flight transition.
	var active: MockTransition = _controller._active_transitions[0]
	assert_true(active.started)
	assert_called(spy, "called")


func test_run_enter_tracks_and_cleans_up_transition():
	# Given: A screen with an enter transition.
	var screen := Screen.new()
	screen.transition_enter = MockTransition.new()
	screen.block_on_enter = true

	# When: run_enter is called.
	_controller.run_enter(screen, _create_scene(), Callable())

	# Then: The transition is tracked.
	assert_eq(_controller._active_transitions.size(), 1)
	var active: MockTransition = _controller._active_transitions[0]

	# When: The transition completes.
	active.complete()

	# Then: The transition is removed from tracking.
	assert_eq(_controller._active_transitions.size(), 0)


func test_run_exit_blocking_delays_teardown_and_callback():
	# Given: A screen with a blocking exit transition.
	var screen := Screen.new()
	screen.transition_exit = MockTransition.new()
	screen.block_on_exit = true
	var spy = double(Spy).new()

	# When: run_exit is called.
	_controller.run_exit(
		screen,
		_create_scene(),
		func(): spy.called("teardown"),
		func(): spy.called("complete"),
	)

	# Then: Neither has fired yet.
	var active: MockTransition = _controller._active_transitions[0]
	assert_true(active.started)
	assert_not_called(spy, "called")

	# When: The transition completes.
	active.complete()

	# Then: Both fire.
	assert_called(spy, "called", ["teardown"])
	assert_called(spy, "called", ["complete"])


func test_run_exit_immediate_teardown_without_transition():
	# Given: A screen with no exit transition.
	var screen := Screen.new()
	var spy = double(Spy).new()

	# When: run_exit is called.
	_controller.run_exit(
		screen,
		_create_scene(),
		func(): spy.called("teardown"),
		func(): spy.called("complete"),
	)

	# Then: Both teardown and callback fire immediately.
	assert_called(spy, "called", ["teardown"])
	assert_called(spy, "called", ["complete"])


func test_run_exit_nonblocking_callback_immediate():
	# Given: A non-blocking exit transition.
	var screen := Screen.new()
	screen.transition_exit = MockTransition.new()
	var spy = double(Spy).new()

	# When: run_exit is called.
	_controller.run_exit(
		screen,
		_create_scene(),
		func(): spy.called("teardown"),
		func(): spy.called("complete"),
	)

	# Then: `on_complete` fires immediately; teardown waits for transition to finish.
	var active: MockTransition = _controller._active_transitions[0]
	assert_true(active.started)
	assert_not_called(spy, "called", ["teardown"])
	assert_called(spy, "called", ["complete"])

	# When: The transition completes.
	active.complete()

	# Then: Teardown fires.
	assert_called(spy, "called", ["teardown"])


func test_stop_all_calls_cancel_cleanup_for_exit():
	# Given: An in-flight exit transition.
	var spy = double(Spy).new()
	_start_exit_transition(func(): spy.called())

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The teardown callable was called.
	assert_called(spy, "called")


func test_stop_all_clears_state_and_unblocks_overlay():
	# Given: Active transitions and blocked input.
	_start_enter_transition()
	_controller.block_input()
	_controller.block_input()
	var overlay := _add_overlay()

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: All state is cleared.
	assert_eq(_controller._active_transitions.size(), 0)
	assert_eq(_controller._cancel_cleanup.size(), 0)
	assert_eq(_controller._input_block_count, 0)
	assert_eq(
		overlay.process_mode,
		Node.PROCESS_MODE_INHERIT,
	)


func test_stop_all_prevents_done_callback():
	# Given: An in-flight blocking enter transition.
	var spy = double(Spy).new()
	var screen := Screen.new()
	screen.transition_enter = MockTransition.new()
	screen.block_on_enter = true
	_controller.run_enter(screen, _create_scene(), func(): spy.called())
	var active: MockTransition = _controller._active_transitions[0]

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: Completing the transition afterward does not fire the callback.
	active.complete()
	assert_not_called(spy, "called")


func test_stop_all_force_reset_skips_cancel_cleanup():
	# Given: An in-flight exit transition.
	var spy = double(Spy).new()
	var transition := _start_exit_transition(func(): spy.called())

	# When: All transitions are force-reset.
	_controller.stop_all(true)

	# Then: Teardown was NOT called (caller handles it).
	assert_not_called(spy, "called")
	assert_true(transition.was_reset)


func test_stop_all_resets_transitions_by_default():
	# Given: An in-flight enter transition (reset_on_interrupt=true by default).
	var transition := _start_enter_transition()

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The transition was reset.
	assert_true(transition.was_reset)


func test_stop_all_stops_without_reset_when_configured():
	# Given: An in-flight transition with reset_on_interrupt=false.
	var transition := _start_enter_transition()
	transition.reset_on_interrupt = false

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The transition was stopped but not reset.
	assert_true(transition.stopped)
	assert_false(transition.was_reset)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Register inner classes so GUT can create doubles.
	register_inner_classes(load("res://screen/manager/controller_test.gd"))

	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each():
	_mock = MockManager.new()
	_mock.name = &"MockManager"
	add_child_autofree(_mock)

	_controller = Controller.new(_mock)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _add_overlay() -> Control:
	var overlay := _create_scene()
	_mock.overlay = overlay
	add_child_autofree(overlay)
	return overlay


func _create_scene() -> Control:
	return autofree(Control.new())


func _start_enter_transition() -> MockTransition:
	var screen := Screen.new()
	screen.transition_enter = MockTransition.new()
	screen.block_on_enter = true

	_controller.run_enter(screen, _create_scene(), Callable())

	return _controller._active_transitions[0]


func _start_exit_transition(
	teardown := Callable(),
) -> MockTransition:
	var screen := Screen.new()
	screen.transition_exit = MockTransition.new()
	screen.block_on_exit = true

	var td: Callable = teardown
	if not td.is_valid():
		td = double(Spy).new().called
	_controller.run_exit(screen, _create_scene(), td, Callable())

	return _controller._active_transitions[0]
