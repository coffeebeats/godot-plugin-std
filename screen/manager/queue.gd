##
## screen/manager/queue.gd
##
## A reentrancy-safe operation queue for the screen manager. Operations are run one at a
## time; if an operation is submitted while another is executing, it is deferred until
## the current one completes.
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

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


## complete signals that the current operation has finished its async phase. Drains the
## queue to run the next pending operation (if any).
func complete() -> void:
	_drain()


## enqueue_or_run queues an operation for deferred execution when called reentrantly
## (from a lifecycle signal handler), or runs it immediately when idle.
func enqueue_or_run(operation: Callable) -> void:
	if _is_operating:
		_queue.append(operation)
		return

	_is_operating = true
	operation.call()

	_drain()


## is_operating returns whether an operation is currently executing.
func is_operating() -> bool:
	return _is_operating


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _drain clears the operating flag and schedules the next queued operation (if any) via
## call_deferred.
func _drain() -> void:
	_is_operating = false

	if _queue.is_empty():
		return

	var next: Callable = _queue.pop_front()
	_run_deferred.call_deferred(next)


## _run_deferred wraps a deferred operation call with the reentrancy guard so signal
## handlers are properly queued.
func _run_deferred(operation: Callable) -> void:
	_is_operating = true
	operation.call()
	_drain()
