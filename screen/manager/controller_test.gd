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

	var _retained_nodes: Dictionary[StringName, Node] = {}


class MockTransition:
	extends "../transition.gd"

	var enter_started := false
	var exit_started := false
	var stopped := false
	var was_reset := false
	var _ctx: StdScreenTransitionContext

	func _enter(context: StdScreenTransitionContext) -> void:
		_ctx = context
		enter_started = true

	func _exit(context: StdScreenTransitionContext) -> void:
		_ctx = context
		exit_started = true

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
	# Given: A transition resource.
	var transition := MockTransition.new()

	# When: run is called for enter.
	var ctx := _create_context()
	ctx._on_done = Callable()
	_controller.run(transition, ctx, true)

	# Then: The tracked transition is a duplicate, not the original.
	assert_not_null(_controller._active_transition)
	assert_ne(_controller._active_transition, transition)

	# When: All transitions are stopped, then run is called for exit.
	_controller.stop_all()
	var ctx2 := _create_context()
	ctx2._on_done = Callable()
	_controller.run(transition, ctx2, false)

	# Then: The tracked transition is a duplicate, not the original.
	assert_not_null(_controller._active_transition)
	assert_ne(_controller._active_transition, transition)


func test_run_enter_starts_enter_on_transition():
	# Given: A transition.
	var transition := MockTransition.new()
	var ctx := _create_context()
	ctx._on_done = Callable()

	# When: run is called with is_enter=true.
	_controller.run(transition, ctx, true)

	# Then: The transition's enter was started.
	var active: MockTransition = _controller._active_transition
	assert_true(active.enter_started)
	assert_false(active.exit_started)


func test_run_exit_starts_exit_on_transition():
	# Given: A transition.
	var transition := MockTransition.new()
	var ctx := _create_context()
	ctx._on_done = Callable()

	# When: run is called with is_enter=false.
	_controller.run(transition, ctx, false)

	# Then: The transition's exit was started.
	var active: MockTransition = _controller._active_transition
	assert_true(active.exit_started)
	assert_false(active.enter_started)


func test_stop_all_calls_cancel_cleanup():
	# Given: An in-flight transition with cancel cleanup.
	var spy = double(Spy).new()
	_start_transition(true, func(): spy.called())

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The cleanup callable was called.
	assert_called(spy, "called")


func test_stop_all_clears_state():
	# Given: An active transition.
	_start_transition(true)

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: All state is cleared.
	assert_null(_controller._active_transition)
	assert_null(_controller._active_context)
	assert_false(_controller._cancel_cleanup.is_valid())


func test_stop_all_prevents_done_callback():
	# Given: An in-flight enter transition.
	var spy = double(Spy).new()
	var ctx := _create_context()
	ctx._on_done = func(): spy.called()
	_controller.run(MockTransition.new(), ctx, true)
	var active: MockTransition = _controller._active_transition

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: Completing the transition afterward does not fire the callback.
	active.complete()
	assert_not_called(spy, "called")


func test_stop_all_force_reset_skips_cancel_cleanup():
	# Given: An in-flight transition with cancel cleanup.
	var spy = double(Spy).new()
	_start_transition(true, func(): spy.called())
	var active: MockTransition = _controller._active_transition

	# When: All transitions are force-reset.
	_controller.stop_all(true)

	# Then: Cleanup was NOT called (caller handles it).
	assert_not_called(spy, "called")
	assert_true(active.was_reset)


func test_stop_all_resets_transitions_by_default():
	# Given: An in-flight transition (reset_on_interrupt=true by default).
	_start_transition(true)
	var active: MockTransition = _controller._active_transition

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The transition was reset.
	assert_true(active.was_reset)


func test_stop_all_stops_without_reset_when_configured():
	# Given: An in-flight transition with reset_on_interrupt=false.
	_start_transition(true)
	var active: MockTransition = _controller._active_transition
	active.reset_on_interrupt = false

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The transition was stopped but not reset.
	assert_true(active.stopped)
	assert_false(active.was_reset)


func test_stop_all_removes_input_blocker():
	# Given: A context with an active input blocker.
	var ctx := _create_context()
	ctx._on_done = Callable()
	ctx.block_input()
	var blocker := (
		ctx
		. get_retained_node(
			StdScreenTransitionContext._BLOCKER_KEY,
		)
	)
	assert_true(blocker.is_inside_tree())
	_controller.run(MockTransition.new(), ctx, true)

	# When: All transitions are stopped.
	_controller.stop_all()

	# Then: The blocker is removed from the tree.
	assert_false(blocker.is_inside_tree())


func test_stop_all_noop_when_no_active_transition():
	# Given: No active transition.
	assert_null(_controller._active_transition)

	# When: stop_all is called.
	_controller.stop_all()

	# Then: No errors occur.
	assert_null(_controller._active_transition)


func test_clear_resets_state():
	# Given: An active transition.
	_start_transition(true)
	assert_not_null(_controller._active_transition)
	assert_not_null(_controller._active_context)

	# When: clear is called.
	_controller.clear()

	# Then: All tracked state is reset.
	assert_null(_controller._active_transition)
	assert_null(_controller._active_context)
	assert_false(_controller._cancel_cleanup.is_valid())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	for node in _mock._retained_nodes.values():
		if is_instance_valid(node):
			node.free()
	_mock._retained_nodes.clear()


func before_all():
	# NOTE: Register inner classes so GUT can create doubles.
	register_inner_classes(load("res://screen/manager/controller_test.gd"))


func before_each():
	_mock = MockManager.new()
	_mock.name = &"MockManager"
	add_child_autofree(_mock)

	_controller = Controller.new(_mock)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_context() -> StdScreenTransitionContext:
	return StdScreenTransitionContext.new(_mock)


func _start_transition(
	is_enter: bool,
	cancel_cleanup := Callable(),
) -> void:
	var ctx := _create_context()
	ctx._on_done = Callable()
	_controller.run(MockTransition.new(), ctx, is_enter, cancel_cleanup)
