# gdlint:ignore=max-public-methods

##
## std/load/loader_test.gd
##
## Tests pertaining to `StdLoader`, run against a scripted engine loader.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _PATH_A := "res://load/_test_a.tscn"
const _PATH_B := "res://load/_test_b.tscn"
const _PATH_C := "res://load/_test_c.tscn"


## FakeBackend scripts the engine's loader, recording what `StdLoader` asks of it and
## answering as a test sets it up to.
class FakeBackend:
	extends StdLoader.Backend

	## blocking_loads lists each path loaded on the calling thread, in order.
	var blocking_loads: Array[String] = []

	## cached maps each cached path to its resource.
	var cached: Dictionary = {}

	## progress maps a path in flight to its progress.
	var progress: Dictionary = {}

	## refused maps a path to the error the engine gives for starting it.
	var refused: Dictionary = {}

	## resources maps a path to the resource its load yields.
	var resources: Dictionary = {}

	## started lists each path whose threaded load was started, in order.
	var started: Array[String] = []

	## statuses maps a path in flight to the engine's status for it.
	var statuses: Dictionary = {}

	## threaded_gets lists each path whose threaded result was fetched, in order.
	var threaded_gets: Array[String] = []

	## ticks is the time, in microseconds.
	var ticks: int = 0

	## finish ends the threaded load of `path` with `resource`, or a failure if null.
	func finish(path: String, resource: Resource) -> void:
		resources[path] = resource
		statuses[path] = (
			ResourceLoader.THREAD_LOAD_LOADED
			if resource
			else ResourceLoader.THREAD_LOAD_FAILED
		)

	func get_cached(path: String) -> Resource:
		return cached.get(path)

	func get_progress(path: String, out: Array) -> ResourceLoader.ThreadLoadStatus:
		out.append(progress.get(path, 0.0))
		return statuses.get(path, ResourceLoader.THREAD_LOAD_IN_PROGRESS)

	func get_threaded(path: String) -> Resource:
		threaded_gets.append(path)
		return resources.get(path)

	func get_ticks_usec() -> int:
		return ticks

	func has_cached(path: String) -> bool:
		return path in cached

	func load_blocking(path: String, _type_hint: String) -> Resource:
		blocking_loads.append(path)

		var resource: Resource = resources.get(path)
		if resource:
			cached[path] = resource

		return resource

	func start(path: String, _type_hint: String) -> Error:
		started.append(path)
		return refused.get(path, OK)


## SlowBackend advances its clock by more than the warning threshold on each load.
class SlowBackend:
	extends FakeBackend

	func load_blocking(path: String, type_hint: String) -> Resource:
		ticks += StdLoader.SLOW_LOAD_USEC * 2
		return super(path, type_hint)


# -- INITIALIZATION ------------------------------------------------------------------ #

var _backend: FakeBackend = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_request_cached_path_is_done_at_once():
	# Given: A cached resource.
	var resource := Resource.new()
	_backend.cached[_PATH_A] = resource

	# When: It is requested.
	var result := StdLoader.request(_PATH_A)

	# Then: The result is done with the resource, and nothing was started.
	assert_true(result.is_done())
	assert_eq(result.resource, resource)
	assert_eq(result.get_error(), OK)
	assert_eq(_backend.started, [] as Array[String])


func test_request_starts_nothing_inside_the_callers_stack():
	# When: A path is requested.
	var result := StdLoader.request(_PATH_A)

	# Then: Nothing was started yet and the result is pending.
	assert_eq(_backend.started, [] as Array[String])
	assert_false(result.is_done())


func test_request_starts_one_load_at_a_time():
	# Given: Two requested paths.
	StdLoader.request(_PATH_A)
	StdLoader.request(_PATH_B)

	# When: The loader steps twice while the first load runs.
	StdLoader._step()
	StdLoader._step()

	# Then: Only the first load was started.
	assert_eq(_backend.started, [_PATH_A] as Array[String])

	# When: The first load ends and the loader steps.
	_backend.finish(_PATH_A, Resource.new())
	StdLoader._step()

	# Then: The second load starts in the same step.
	assert_eq(_backend.started, [_PATH_A, _PATH_B] as Array[String])


func test_request_reports_once_from_the_step():
	# Given: A requested path whose load has started.
	var result := StdLoader.request(_PATH_A)
	watch_signals(result)
	StdLoader._step()

	# Given: The engine finishes the load.
	var resource := Resource.new()
	_backend.finish(_PATH_A, resource)

	# Then: The result hasn't reported before the loader steps.
	assert_signal_not_emitted(result, "done")
	assert_false(result.is_done())

	# When: The loader steps twice.
	StdLoader._step()
	StdLoader._step()

	# Then: The result reported once, with the resource.
	assert_signal_emit_count(result, "done", 1)
	assert_true(result.is_done())
	assert_eq(result.resource, resource)


func test_request_repeated_path_shares_one_result():
	# When: The same path is requested twice.
	var first := StdLoader.request(_PATH_A)
	var second := StdLoader.request(_PATH_A)

	# Then: Both requests share one result.
	assert_eq(first, second)


func test_request_uid_and_path_share_one_result():
	# Given: A uid naming a path.
	var id := ResourceUID.create_id()
	ResourceUID.add_id(id, _PATH_A)

	# When: The path is requested by uid and then by path.
	var by_uid := StdLoader.request(ResourceUID.id_to_text(id))
	var by_path := StdLoader.request(_PATH_A)

	# Then: Both requests share one result, known by its path.
	assert_eq(by_uid, by_path)
	assert_eq(by_uid.path, _PATH_A)

	ResourceUID.remove_id(id)


func test_request_urgent_starts_next():
	# Given: A request waiting behind one in flight.
	StdLoader.request(_PATH_A)
	StdLoader._step()
	StdLoader.request(_PATH_B)

	# When: A third path is requested urgently.
	StdLoader.request(_PATH_C, "", true)

	# When: The load in flight ends and the loader steps.
	_backend.finish(_PATH_A, Resource.new())
	StdLoader._step()

	# Then: The urgent request started next.
	assert_eq(_backend.started, [_PATH_A, _PATH_C] as Array[String])


func test_request_urgent_repeat_moves_waiting_request_to_front():
	# Given: Two waiting requests behind one in flight.
	StdLoader.request(_PATH_A)
	StdLoader._step()
	StdLoader.request(_PATH_B)
	StdLoader.request(_PATH_C)

	# When: The last is requested again, urgently.
	StdLoader.request(_PATH_C, "", true)

	# When: The load in flight ends and the loader steps.
	_backend.finish(_PATH_A, Resource.new())
	StdLoader._step()

	# Then: The repeated request started next.
	assert_eq(_backend.started, [_PATH_A, _PATH_C] as Array[String])


func test_request_refused_by_the_engine_reports_failure():
	# Given: A path the engine refuses to start.
	_backend.refused[_PATH_A] = ERR_FILE_NOT_FOUND
	var result := StdLoader.request(_PATH_A)
	watch_signals(result)

	# When: The loader steps.
	StdLoader._step()

	# Then: The result reported a failure.
	assert_signal_emit_count(result, "done", 1)
	assert_eq(result.get_error(), FAILED)
	assert_null(result.resource)
	assert_push_error("Failed to load resource.")


func test_request_failed_load_reports_failure():
	# Given: A requested path whose load has started.
	var result := StdLoader.request(_PATH_A)
	StdLoader._step()

	# When: The engine fails the load and the loader steps.
	_backend.finish(_PATH_A, null)
	StdLoader._step()

	# Then: The result reported a failure.
	assert_true(result.is_done())
	assert_eq(result.get_error(), FAILED)
	assert_push_error("Failed to load resource.")


func test_step_finishes_waiting_request_once_cached():
	# Given: A request waiting behind one in flight.
	StdLoader.request(_PATH_A)
	StdLoader._step()
	var waiting := StdLoader.request(_PATH_B)

	# Given: The waiting path is cached by other means.
	var resource := Resource.new()
	_backend.cached[_PATH_B] = resource

	# When: The loader steps.
	StdLoader._step()

	# Then: The waiting request is done without being started.
	assert_true(waiting.is_done())
	assert_eq(waiting.resource, resource)
	assert_eq(_backend.started, [_PATH_A] as Array[String])


func test_step_disconnects_once_idle():
	# Given: A requested path, which connects the step.
	var tree := get_tree()
	StdLoader.request(_PATH_A)
	assert_true(tree.process_frame.is_connected(StdLoader._step))

	# When: Its load runs to the end.
	StdLoader._step()
	_backend.finish(_PATH_A, Resource.new())
	StdLoader._step()

	# Then: The step is no longer connected.
	assert_false(tree.process_frame.is_connected(StdLoader._step))


func test_step_reports_stalled_load_once():
	# Given: A load in flight that never progresses, beside a waiting request.
	StdLoader.request(_PATH_A)
	StdLoader.request(_PATH_B)
	StdLoader._step()

	# When: Frames pass, each longer than the cap, for longer than the stall limit.
	var frames := ceili(float(StdLoader.STALL_USEC) / StdLoader.STALL_FRAME_USEC) + 1
	for i in frames * 2:
		_backend.ticks += StdLoader.STALL_FRAME_USEC * 10
		StdLoader._step()

	# Then: The stall was reported once.
	assert_push_error("Threaded load made no progress.")
	assert_push_error_count(1)


func test_step_counts_no_stall_while_loading_progresses():
	# Given: A load in flight.
	StdLoader.request(_PATH_A)
	StdLoader._step()

	# When: Frames pass for longer than the stall limit while it progresses.
	var frames := ceili(float(StdLoader.STALL_USEC) / StdLoader.STALL_FRAME_USEC) + 1
	for i in frames:
		_backend.ticks += StdLoader.STALL_FRAME_USEC
		_backend.progress[_PATH_A] = float(i) / frames
		StdLoader._step()

	# Then: No stall was reported.
	assert_push_error_count(0)


func test_load_now_cached_path_returns_at_once():
	# Given: A cached resource.
	var resource := Resource.new()
	_backend.cached[_PATH_A] = resource

	# When: It is loaded now.
	var loaded := StdLoader.load_now(_PATH_A)

	# Then: The cached resource is returned without a load.
	assert_eq(loaded, resource)
	assert_eq(_backend.blocking_loads, [] as Array[String])


func test_load_now_in_flight_path_waits_for_that_load():
	# Given: A request in flight.
	var result := StdLoader.request(_PATH_A)
	watch_signals(result)
	StdLoader._step()
	var resource := Resource.new()
	_backend.resources[_PATH_A] = resource

	# When: The same path is loaded now.
	var loaded := StdLoader.load_now(_PATH_A)

	# Then: It waited for the request in flight rather than loading again.
	assert_eq(loaded, resource)
	assert_eq(_backend.threaded_gets, [_PATH_A] as Array[String])
	assert_eq(_backend.blocking_loads, [] as Array[String])

	# Then: The request hasn't reported inside the caller's stack.
	assert_signal_not_emitted(result, "done")

	# When: The loader steps.
	StdLoader._step()

	# Then: The request reported once, with the resource, fetched only once.
	assert_signal_emit_count(result, "done", 1)
	assert_eq(result.resource, resource)
	assert_eq(_backend.threaded_gets, [_PATH_A] as Array[String])


func test_load_now_unrelated_path_never_waits_on_the_load_in_flight():
	# Given: A request in flight.
	StdLoader.request(_PATH_A)
	StdLoader._step()

	# Given: Another path's resource.
	var resource := Resource.new()
	_backend.resources[_PATH_B] = resource

	# When: The other path is loaded now.
	var loaded := StdLoader.load_now(_PATH_B)

	# Then: It loaded on the calling thread, never waiting on the request in flight.
	assert_eq(loaded, resource)
	assert_eq(_backend.blocking_loads, [_PATH_B] as Array[String])
	assert_eq(_backend.threaded_gets, [] as Array[String])


func test_load_now_waiting_path_finishes_its_request_at_the_next_step():
	# Given: A request waiting behind one in flight.
	StdLoader.request(_PATH_A)
	StdLoader._step()
	var waiting := StdLoader.request(_PATH_B)

	# Given: The waiting path's resource.
	var resource := Resource.new()
	_backend.resources[_PATH_B] = resource

	# When: The waiting path is loaded now.
	StdLoader.load_now(_PATH_B)

	# When: The loader steps.
	StdLoader._step()

	# Then: The waiting request is done with that resource, never started.
	assert_true(waiting.is_done())
	assert_eq(waiting.resource, resource)
	assert_eq(_backend.started, [_PATH_A] as Array[String])


func test_load_now_slow_load_warns():
	# Given: A load which takes longer than the warning threshold.
	_backend.resources[_PATH_A] = Resource.new()
	var slow := SlowBackend.new()
	slow.resources = _backend.resources
	StdLoader._set_backend(slow)

	# When: It is loaded now.
	StdLoader.load_now(_PATH_A)

	# Then: The slow load was reported.
	assert_push_warning("Blocking load was slow.")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	StdLoader._reset()


func before_each() -> void:
	StdLoader._reset()

	_backend = FakeBackend.new()
	StdLoader._set_backend(_backend)
