##
## std/thread/result.gd
##
## StdThreadWorkerResult is an object which contains the results of a worker's job run.
##

class_name StdThreadWorkerResult
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## done is emitted when this result is first completed.
signal done(error: Error)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _error: Error = ERR_BUSY
var _is_done: bool = false
var _mutex: Mutex = Mutex.new()
var _semaphore: Semaphore = Semaphore.new()
var _semaphore_waiting_count: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## failed is a convenience method for constructing a *finished* result object that
## contains the specified error.
static func failed(error: Error) -> StdThreadWorkerResult:
	var result := StdThreadWorkerResult.new()
	result._is_done = true
	result._error = error
	return result


## finish is used to set the state of the result object once the underlying job run has
## been completed.
##
## NOTE: This is intended to be called by a `StdThreadWorker` upon it finishing a run.
func finish(error: Error) -> void:
	_mutex.lock()

	while _semaphore_waiting_count:
		_semaphore_waiting_count -= 1
		_semaphore.post()

	if _is_done:
		assert(false, "invalid state; result already finished")
		_mutex.unlock()
		return

	_is_done = true
	_error = error

	done.emit.call_deferred(error)  # NOTE: This method can be run from a thread.

	_mutex.unlock()


## get_error returns the error status for the result. If the result is not yet known,
## then this will return `ERR_BUSY`.
func get_error() -> Error:
	_mutex.lock()
	var error := _error
	_mutex.unlock()

	return error


## is_done returns whether the job run corresponding to this result has completed.
func is_done() -> bool:
	_mutex.lock()
	var is_finished := _is_done
	_mutex.unlock()

	return is_finished


## lock locks this result object, preventing other threads from modifying it.
##
## NOTE: This method will block until the lock is acquired.
func lock() -> void:
	_mutex.lock()


## unlock releases a previously acquired lock for this result object.
##
## NOTE: This should only be called if the lock is currently held by the calling thread.
func unlock() -> void:
	_mutex.unlock()


## wait blocks the current thread until the job run correspodning to this result has
## completed. This is safe to call from multiple threads at the same time.
func wait() -> Error:
	_mutex.lock()

	if _is_done:
		var error := _error
		_mutex.unlock()
		return error

	_semaphore_waiting_count += 1

	var semaphore := _semaphore

	_mutex.unlock()

	semaphore.wait()

	return get_error()
