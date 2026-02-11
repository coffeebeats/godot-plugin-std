##
## screen/manager/queue_test.gd
##
## Tests pertaining to the operation queue class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const OperationQueue := preload("queue.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Spy is a minimal class used for creating GUT doubles that track method calls from
## within queue operations.
class Spy:
	extends RefCounted

	func called(_tag: String = "") -> void:
		pass


# -- INITIALIZATION ------------------------------------------------------------------ #

var _queue: OperationQueue

# -- TEST METHODS -------------------------------------------------------------------- #


func test_enqueue_or_run_idle_executes_operation_immediately():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: An idle queue.
	assert_false(_queue.is_operating())

	# When: An operation is submitted.
	_queue.enqueue_or_run(func(): spy.called())

	# Then: The operation executed synchronously.
	assert_called(spy, "called")


func test_enqueue_or_run_sets_operating_during_sync_phase():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: An idle queue.
	assert_false(_queue.is_operating())

	# When: An operation captures the guard state.
	_queue.enqueue_or_run(
		func(): spy.called(str(_queue.is_operating())),
	)

	# Then: The guard was active during the sync phase.
	assert_called(spy, "called", ["true"])

	# Then: The guard is cleared after the sync phase.
	assert_false(_queue.is_operating())


func test_enqueue_or_run_reentrant_defers_operation():
	# Given: A spy to track inner execution.
	var spy = double(Spy).new()

	# Given: An idle queue.
	assert_false(_queue.is_operating())

	# When: A nested operation is submitted from within an active one.
	_queue.enqueue_or_run(func(): _queue.enqueue_or_run(func(): spy.called()))

	# Then: The inner operation has not run (deferred to next frame).
	assert_not_called(spy, "called")


func test_enqueue_or_run_reentrant_drains_on_complete():
	# Given: A spy to track inner execution.
	var spy = double(Spy).new()

	# Given: An idle queue.
	assert_false(_queue.is_operating())

	# Given: A completed operation that enqueued a nested one.
	_queue.enqueue_or_run(
		func():
			_queue.enqueue_or_run(func(): spy.called())
			_queue.complete(),
	)

	# When: A frame passes, allowing `call_deferred` to fire.
	await get_tree().process_frame

	# Then: The deferred operation has executed.
	assert_called(spy, "called")


func test_enqueue_or_run_reentrant_preserves_fifo_order():
	# Given: A spy to track inner execution.
	var spy = double(Spy).new()

	# Given: An idle queue.
	assert_false(_queue.is_operating())

	# Given: Multiple deferred operations are enqueued and completed.
	_queue.enqueue_or_run(
		func():
			_queue.enqueue_or_run(
				func():
					spy.called("1")
					_queue.complete(),
			)
			_queue.enqueue_or_run(
				func():
					spy.called("2")
					_queue.complete(),
			)
			_queue.enqueue_or_run(
				func():
					spy.called("3")
					_queue.complete(),
			)
			_queue.complete(),
	)

	# When: Enough frames pass for all deferred operations to drain.
	await wait_physics_frames(4)

	# Then: Operations executed in FIFO order.
	assert_eq(get_call_parameters(spy.called, 0), ["1"])
	assert_eq(get_call_parameters(spy.called, 1), ["2"])
	assert_eq(get_call_parameters(spy.called, 2), ["3"])


func test_clear_prevents_queued_operations_from_running():
	# Given: A spy to track inner execution.
	var spy = double(Spy).new()

	# Given: An idle queue.
	assert_false(_queue.is_operating())

	# Given: Multiple deferred operations are enqueued.
	_queue.enqueue_or_run(
		func():
			_queue.enqueue_or_run(
				func():
					spy.called("first")
					_queue.complete(),
			)
			_queue.enqueue_or_run(
				func():
					spy.called("second")
					_queue.complete(),
			)
			_queue.complete(),
	)

	# When: The queue is cleared before the deferred calls fire.
	_queue.clear()
	await wait_physics_frames(2)

	# Then: Only the first operation ran.
	assert_called(spy, "called", ["first"])
	assert_not_called(spy, "called", ["second"])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Register inner classes so GUT can create doubles of them.
	register_inner_classes(load("res://screen/manager/queue_test.gd"))

	# NOTE: Hide unactionable errors when using object doubles.
	(
		ProjectSettings
		. set(
			"debug/gdscript/warnings/native_method_override",
			false,
		)
	)


func before_each():
	var node := Node.new()
	add_child_autofree(node)
	_queue = OperationQueue.new(node)
