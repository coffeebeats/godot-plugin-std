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


func test_enqueue_or_run_during_async_phase_drains():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: An operation in its async phase (sync returned, `complete` not yet called).
	_queue.enqueue_or_run(func(): pass)

	# When: A new operation is submitted externally.
	_queue.enqueue_or_run(func(): spy.called())

	# Then: Not run synchronously (scheduled for next frame).
	assert_not_called(spy, "called")

	# When: A frame passes, allowing call_deferred to fire.
	await get_tree().process_frame

	# Then: The new operation has executed.
	assert_called(spy, "called")


func test_enqueue_or_run_while_held_waits_for_complete():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: An operation waiting for its loads.
	_queue.enqueue_or_run(func(): _queue.hold())

	# When: A new operation is submitted.
	_queue.enqueue_or_run(func(): spy.called())

	# When: A frame passes.
	await get_tree().process_frame

	# Then: It hasn't run, and the queue is operating and unsettled.
	assert_not_called(spy, "called")
	assert_true(_queue.is_operating())
	assert_false(_queue.is_settled())

	# When: The waiting operation resumes and completes.
	_queue.resume(func(): _queue.complete())

	# When: A frame passes.
	await get_tree().process_frame

	# Then: The new operation has executed.
	assert_called(spy, "called")


func test_resume_holds_calls_until_complete():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: An operation waiting for its loads.
	_queue.enqueue_or_run(func(): _queue.hold())

	# When: It resumes, submitting an operation from its synchronous phase.
	_queue.resume(func(): _queue.enqueue_or_run(func(): spy.called()))
	await get_tree().process_frame

	# Then: The submitted operation waits for the resumed one to complete.
	assert_not_called(spy, "called")
	assert_false(_queue.is_operating())


func test_complete_emptying_the_queue_emits_settled():
	# Given: A running operation.
	_queue.enqueue_or_run(func(): pass)
	watch_signals(_queue)
	assert_false(_queue.is_settled())

	# When: It completes with nothing queued.
	_queue.complete()

	# Then: The queue settled.
	assert_signal_emit_count(_queue, "settled", 1)
	assert_true(_queue.is_settled())


func test_complete_with_queued_operation_emits_settled_after_it():
	# Given: A running operation with another queued behind it.
	_queue.enqueue_or_run(func(): _queue.enqueue_or_run(func(): _queue.complete()))
	watch_signals(_queue)

	# When: The running operation completes.
	_queue.complete()

	# Then: The queue hasn't settled while the next operation is pending.
	assert_signal_not_emitted(_queue, "settled")
	assert_false(_queue.is_settled())

	# When: A frame passes and the queued operation runs and completes.
	await get_tree().process_frame

	# Then: The queue settled once.
	assert_signal_emit_count(_queue, "settled", 1)


func test_reset_drops_operations_and_emits_settled():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: A waiting operation with another queued behind it.
	_queue.enqueue_or_run(func(): _queue.hold())
	_queue.enqueue_or_run(func(): spy.called())
	watch_signals(_queue)

	# When: The queue is reset.
	_queue.reset()

	# When: A frame passes.
	await get_tree().process_frame

	# Then: Nothing more ran, and the queue settled.
	assert_not_called(spy, "called")
	assert_signal_emit_count(_queue, "settled", 1)
	assert_true(_queue.is_settled())


func test_defer_runs_a_call_at_the_end_of_the_frame():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: An idle queue deferring its calls.
	_queue.defer()

	# When: An operation is enqueued.
	_queue.enqueue_or_run(
		func():
			spy.called()
			_queue.complete()
	)

	# Then: It waits, and the queue is not settled.
	assert_not_called(spy, "called")
	assert_false(_queue.is_settled())

	# Then: It ran by the end of the frame, which ended the deferral.
	await get_tree().process_frame
	assert_called(spy, "called")
	assert_false(_queue.is_deferring())
	assert_true(_queue.is_settled())


func test_reset_ends_a_deferral():
	# Given: A spy to track execution.
	var spy = double(Spy).new()

	# Given: A queue deferring its calls.
	_queue.defer()

	# Given: The queue was reset.
	_queue.reset()

	# When: An operation is enqueued.
	_queue.enqueue_or_run(func(): spy.called())

	# Then: It ran at once.
	assert_called(spy, "called")
	assert_false(_queue.is_deferring())


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
