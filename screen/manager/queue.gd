##
## screen/manager/queue.gd
##
## A reentrancy-safe operation queue for the screen manager. Operations run one at a
## time; reentrant calls (during the sync phase) are deferred until `complete` is
## called. Calls during the async phase enqueue and drain immediately, allowing the next
## operation to interrupt (e.g. cancel in-flight transitions).
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

## _drain_scheduled is true while a popped item has been scheduled via `call_deferred`
## but has not yet started executing. Prevents multiple items from being dispatched in
## the same frame.
var _drain_scheduled: bool = false

## _is_active is true from the start of an operation until `complete` is called. Spans
## both the sync and async phases.
var _is_active: bool = false

## _is_operating is true while an operation's synchronous phase is executing.
var _is_operating: bool = false

## _owner is the `Node` used for call_deferred scheduling.
var _owner: Node

## _queue holds navigation callables deferred during reentrancy.
var _queue: Array[Callable] = []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(owner: Node) -> void:
	_owner = owner


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear removes all pending operations from the queue.
func clear() -> void:
	_queue.clear()


## complete signals that the current operation has finished, clearing the active flag
## and draining the queue.
func complete() -> void:
	if not _drain_scheduled:
		_is_active = false

	_drain()


## enqueue_or_run has three behaviors depending on queue state:
##  - Sync phase: append only (reentrant guard; waits for `complete`).
##  - Async phase or drain pending: append and drain (responsive interruption).
##  - Idle: run immediately.
##
## NOTE: Operations must call `complete` when finished.
func enqueue_or_run(operation: Callable) -> void:
	if _is_operating:
		_queue.append(operation)
		return

	if _is_active or _drain_scheduled:
		_queue.append(operation)
		_drain()
		return

	_is_operating = true
	_is_active = true

	operation.call()

	_is_operating = false


## is_operating returns whether an operation's synchronous phase is executing.
func is_operating() -> bool:
	return _is_operating


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _drain schedules the next queued operation via `call_deferred`.
func _drain() -> void:
	if _drain_scheduled or _queue.is_empty():
		return

	_drain_scheduled = true

	var next: Callable = _queue.pop_front()
	_run_deferred.call_deferred(next)


## _run_deferred wraps a deferred operation call with the reentrancy guard so signal
## handlers are properly queued.
func _run_deferred(operation: Callable) -> void:
	_drain_scheduled = false
	_is_operating = true
	_is_active = true

	operation.call()

	_is_operating = false
