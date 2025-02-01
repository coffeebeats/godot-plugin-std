##
## std/thread/worker.gd
##
## StdThreadWorker is a base class for a node which executes a predefined job in its own
## long-lived thread.
##

class_name StdThreadWorker
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Thread")

## thread_priority controls the thread priority of the thread in which the worker runs.
@export var thread_priority: Thread.Priority = Thread.PRIORITY_NORMAL

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_running: bool = false
var _worker_mutex := Mutex.new()
var _worker_result: StdThreadWorkerResult = null
var _worker_semaphore := Semaphore.new()
var _worker_thread: Thread = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_thread_running returns whether this worker's thread is currently alive.
func is_thread_running() -> bool:
	assert(is_inside_tree(), "invalid state; must be in scene tree")

	_worker_mutex.lock()
	var value := _is_running
	_worker_mutex.unlock()

	return value


## is_worker_in_progress returns whether this worker is currently executing its task.
func is_worker_in_progress() -> bool:
	assert(is_inside_tree(), "invalid state; must be in scene tree")

	_worker_mutex.lock()
	var value := _worker_result != null
	_worker_mutex.unlock()

	return value


## run executes the worker, immediately returning a result which can be used to track
## the progress of the current invocation.
##
## NOTE: Only one invocation may occur at a time.
func run() -> StdThreadWorkerResult:
	assert(is_inside_tree(), "invalid state; must be in scene tree")

	_worker_mutex.lock()

	if _worker_result is StdThreadWorkerResult:
		_worker_mutex.unlock()
		return StdThreadWorkerResult.failed(ERR_BUSY)

	var result := _create_worker_result()
	assert(result is StdThreadWorkerResult, "invalid return value; missing result")
	_worker_result = result

	_worker_semaphore.post()
	_worker_mutex.unlock()

	return result


## wait causes the calling thread to wait until any in-progress task is completed. This
## is safe to call even if the worker is not currently in progress.
func wait() -> void:
	assert(is_inside_tree(), "invalid state; must be in scene tree")

	_worker_mutex.lock()
	var result := _worker_result
	_worker_mutex.unlock()

	if result:
		result.wait()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree():
	wait()  # Don't exit until work completes.

	_worker_mutex.lock()
	_is_running = false

	_worker_semaphore.post()
	_worker_mutex.unlock()

	_worker_thread.wait_to_finish()


func _ready() -> void:
	_is_running = true
	_worker_thread = Thread.new()
	_worker_thread.start(_worker_thread_impl, thread_priority)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _create_worker_result can be overridden to custom the type of result object used by
## the worker.
func _create_worker_result() -> StdThreadWorkerResult:
	return StdThreadWorkerResult.new()


## _worker_impl is an abstract method that defines the worker's job. This should be
## overridden by child classes to define the work that will be done in the thread.
##
## NOTE: This will be called once per worker invocation.
func _worker_impl() -> Error:
	assert(false, "unimplemented")
	return FAILED


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _worker_thread_impl() -> void:
	while true:
		_worker_semaphore.wait()

		_worker_mutex.lock()
		var should_exit := not _is_running
		var result := _worker_result
		_worker_mutex.unlock()

		if should_exit:
			break

		if not result:
			assert(false, "invalid state; missing result")
			continue

		var err := _worker_impl()

		_worker_mutex.lock()

		_worker_result = null
		result.finish(err)

		_worker_mutex.unlock()
