##
## Tests pertaining to the `StdThreadWorker` class.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #


class ThreadWorkerTest:
	extends StdThreadWorker

	var result: Error = OK
	var semaphore := Semaphore.new()

	func _worker_impl() -> Error:
		semaphore.wait()
		return result


var worker: ThreadWorkerTest = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_worker_completes_successfully():
	# Given: A new worker that will succeed.
	worker = ThreadWorkerTest.new()

	# Given: The worker is added to the scene.
	add_child(worker)

	# When: The worker is executed.
	var result := worker.run()
	assert_not_null(result)

	# Then: The result is in progress.
	assert_false(result.is_done())

	# When: The result is waited upon.
	worker.semaphore.post()  # Let the worker resume execution.
	var err := result.wait()

	# Then: The error matches expectations.
	assert_eq(err, OK)


func test_worker_fails_successfully():
	# Given: A new worker that will fail.
	worker = ThreadWorkerTest.new()
	worker.result = FAILED

	# Given: The worker is added to the scene.
	add_child(worker)

	# When: The worker is executed.
	var result := worker.run()
	assert_not_null(result)

	# Then: The result is in progress.
	assert_false(result.is_done())

	# When: The result is waited upon.
	worker.semaphore.post()  # Let the worker resume execution.
	var err := result.wait()

	# Then: The error matches expectations.
	assert_eq(err, FAILED)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	remove_child(worker)
	assert_false(worker._worker_thread.is_alive())
	worker.free()


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
