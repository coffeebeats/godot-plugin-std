##
## screen/manager/queue.gd
##
## A reentrancy-safe operation queue for the screen manager. Operations run one at a
## time, in call order. A call made while an operation's synchronous phase runs, or
## while it waits for its loads, is held until that operation completes. A call made
## while an operation's transition runs is queued and drained at once, and the manager
## completes the running operation, skipping the rest of its transition, before it runs
## the next. A call made while the queue defers, from `defer` to the end of that frame,
## is queued and drained at once, too.
##

extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## settled is emitted whenever the queue empties, with no operation running, waiting or
## queued.
signal settled

# -- INITIALIZATION ------------------------------------------------------------------ #

## _drain_scheduled is true while a popped item has been scheduled via `call_deferred`
## but has not yet started executing. Prevents multiple items from being dispatched in
## the same frame.
var _drain_scheduled: bool = false

## _generation counts the times the queue was reset, so that an item scheduled before a
## reset doesn't run after it.
var _generation: int = 0

## _is_active is true from the start of an operation until `complete` is called,
## spanning the synchronous phase, any wait for loads and any transition.
var _is_active: bool = false

## _is_deferring is true from `defer` until the end of that frame, or a reset.
var _is_deferring: bool = false

## _is_held is true while an operation waits for its loads.
var _is_held: bool = false

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
	_is_active = false
	_is_held = false

	if not _queue.is_empty():
		_drain()
	elif not _drain_scheduled:
		settled.emit()


## defer queues every call made until the end of the frame, so that each runs then, in
## call order, rather than at once. A reset ends it.
func defer() -> void:
	if _is_deferring:
		return

	_is_deferring = true
	_end_defer.call_deferred(_generation)


## enqueue_or_run has three behaviors depending on queue state:
##  - Sync phase, a wait for loads, or a drain pending: append only, which waits for
##    `complete` (or for the pending drain).
##  - Transition running, or deferring: append and drain, so the next operation runs at
##    the end of the frame, completing any running first.
##  - Idle: run immediately.
##
## NOTE: Operations must call `complete` when finished.
func enqueue_or_run(operation: Callable) -> void:
	if _is_operating or _is_held or _drain_scheduled:
		_queue.append(operation)
		return

	if _is_active or _is_deferring:
		_queue.append(operation)
		_drain()
		return

	_is_operating = true
	_is_active = true

	operation.call()

	_end_sync()


## hold keeps every later call queued while the current operation waits for its loads.
func hold() -> void:
	assert(_is_active, "invalid state; no operation is running")
	_is_held = true


## is_deferring returns whether calls wait for the end of the frame, after `defer`.
func is_deferring() -> bool:
	return _is_deferring


## is_operating returns whether an operation's synchronous phase is executing, or an
## operation waits for its loads.
func is_operating() -> bool:
	return _is_operating or _is_held


## is_settled returns whether no operation is running, waiting or queued.
func is_settled() -> bool:
	return not _is_active and not _drain_scheduled and _queue.is_empty()


## release ends the hold `hold` placed, without running anything.
func release() -> void:
	_is_held = false


## reset drops every operation, running, waiting or queued, as the manager does when it
## leaves the tree, and emits `settled` if any was dropped.
func reset() -> void:
	var was_settled := is_settled()

	_generation += 1
	_drain_scheduled = false
	_is_active = false
	_is_deferring = false
	_is_held = false
	_is_operating = false
	_queue.clear()

	if not was_settled:
		settled.emit()


## resume ends the hold and runs `operation` as the waiting operation's synchronous
## phase, so a call it makes is held until the operation completes.
func resume(operation: Callable) -> void:
	_is_held = false
	_is_operating = true

	operation.call()

	_end_sync()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _end_defer ends the deferral `defer` began, unless a reset has ended it since.
func _end_defer(generation: int) -> void:
	if generation == _generation:
		_is_deferring = false


## _end_sync ends a synchronous phase. A call made after the operation completed within
## it, such as from a `settled` handler, was only queued, so it is drained here.
func _end_sync() -> void:
	_is_operating = false

	if not _is_active:
		_drain()


## _drain schedules the next queued operation via `call_deferred`.
func _drain() -> void:
	if _drain_scheduled or _queue.is_empty():
		return

	_drain_scheduled = true

	var next: Callable = _queue.pop_front()
	_run_deferred.call_deferred(next, _generation)


## _run_deferred wraps a deferred operation call with the reentrancy guard so signal
## handlers are properly queued.
func _run_deferred(operation: Callable, generation: int) -> void:
	if generation != _generation:
		return

	_drain_scheduled = false
	_is_operating = true
	_is_active = true

	operation.call()

	_end_sync()
