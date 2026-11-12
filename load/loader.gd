##
## std/load/loader.gd
##
## StdLoader runs the process's threaded resource loads, one at a time. A caller asks
## for a resource with `request` and gets a `Result` that reports once the load ends. A
## load starts, finishes and reports only in the loader's per-frame step, never inside
## a caller's stack, so every result reports exactly once and from one place.
##
## Its state belongs to the process rather than to a node, since "one load in flight"
## is a property of the process. Nothing here waits for a load it did not ask for:
## `load_now`, the one blocking call, waits only for the load it names.
##
## NOTE: Godot 4.6 to 4.8 deadlock when a thread compiling a script waits in the loader
## for a resource another thread is loading. Loading one request at a time removes the
## second loading thread std would otherwise add; see the `preload` checker rule for
## what keeps a compile from waiting at all.
##

class_name StdLoader
extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

## SLOW_LOAD_USEC is how long a blocking load may take before `load_now` warns of it.
const SLOW_LOAD_USEC := 100000

## STALL_USEC is how long a threaded load may go without progress, in frame time,
## before the step reports it.
const STALL_USEC := 20000000

## STALL_FRAME_USEC caps the frame time a single step counts toward `STALL_USEC`, so a
## hitch or a breakpoint doesn't count as a stall.
const STALL_FRAME_USEC := 100000


## Result is one request's handle. It reports once, through `done`, when the load ends,
## whether or not it succeeded. A result for a resource already cached is done when
## `request` returns, and never emits `done`.
class Result:
	extends RefCounted

	## done is emitted once the load ends, from the loader's step.
	signal done

	## path is the requested resource's path, a `uid://` resolved to its file.
	var path: String = ""

	## resource is the loaded resource, or null until it loads or if it failed.
	var resource: Resource = null

	## status is the engine's status for the load.
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS

	var _fetched: bool = false
	var _type_hint: String = ""

	## get_error returns the load's error, `OK` while it runs and once it succeeded.
	func get_error() -> Error:
		match status:
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return ERR_INVALID_PARAMETER
			ResourceLoader.THREAD_LOAD_FAILED:
				return FAILED

		return OK

	## is_done returns whether the load ended, which doesn't imply it succeeded.
	func is_done() -> bool:
		return status != ResourceLoader.THREAD_LOAD_IN_PROGRESS


## Backend is the engine's resource loader as `StdLoader` uses it. A test replaces it
## through `_set_backend` to script the engine.
class Backend:
	extends RefCounted

	## get_cached returns the cached resource at `path`, or null if none is cached.
	func get_cached(path: String) -> Resource:
		return ResourceLoader.get_cached_ref(path)

	## get_progress returns the status of the threaded load of `path`, and writes its
	## progress, from 0 to 1, into `progress`.
	func get_progress(path: String, progress: Array) -> ResourceLoader.ThreadLoadStatus:
		return ResourceLoader.load_threaded_get_status(path, progress)

	## get_threaded returns the result of the threaded load of `path`, waiting for it to
	## end if it hasn't.
	func get_threaded(path: String) -> Resource:
		return ResourceLoader.load_threaded_get(path)

	## get_ticks_usec returns the time, which the stall report measures.
	func get_ticks_usec() -> int:
		return Time.get_ticks_usec()

	## has_cached returns whether a resource is cached at `path`.
	func has_cached(path: String) -> bool:
		return ResourceLoader.has_cached(path)

	## load_blocking loads `path` on the calling thread.
	func load_blocking(path: String, type_hint: String) -> Resource:
		return ResourceLoader.load(path, type_hint)

	## start begins a threaded load of `path`, without sub-threads.
	func start(path: String, type_hint: String) -> Error:
		return ResourceLoader.load_threaded_request(path, type_hint, false)


# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/load/loader")  # gdlint:ignore=class-definitions-order,max-line-length

## _backend is the engine's loader, or a test's script of it.
static var _backend: Backend = Backend.new()

## _in_flight is the one threaded request outstanding, or null.
static var _in_flight: Result = null

## _last_step_usec is when the step last ran, or -1 before it has.
static var _last_step_usec: int = -1

## _queue holds the requests waiting to start, the next first.
static var _queue: Array[Result] = []

## _results maps each path waiting or in flight to its result, so repeated requests
## share one.
static var _results: Dictionary[String, Result] = {}

## _stall_progress is the in-flight request's progress when it last moved.
static var _stall_progress: float = -1.0

## _stall_reported is whether the in-flight request's stall was already reported.
static var _stall_reported: bool = false

## _stall_usec is the frame time the in-flight request has gone without progress.
static var _stall_usec: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_now returns the resource at `path`, loading it on the calling thread if it must.
## A cached resource returns at once. If `path` is the request in flight, this waits for
## that request alone, through the engine's wait, which keeps the main message queue
## moving; otherwise it loads `path` beside whatever is in flight, never waiting on an
## unrelated load. It warns when the load took over `SLOW_LOAD_USEC`.
##
## NOTE: This is the one blocking load std offers, so every blocking load shows up here.
static func load_now(path: String, type_hint: String = "") -> Resource:
	var key := _to_key(path)

	if _backend.has_cached(key):
		return _backend.get_cached(key)

	var started := _backend.get_ticks_usec()
	var resource: Resource = null

	if _in_flight and _in_flight.path == key:
		# NOTE: The engine hands a threaded load's result over once, so the step
		# reports the request with what this fetched instead of asking again.
		if not _in_flight._fetched:
			_in_flight.resource = _backend.get_threaded(key)
			_in_flight._fetched = true

		resource = _in_flight.resource
	else:
		resource = _backend.load_blocking(key, type_hint)

	var elapsed := _backend.get_ticks_usec() - started
	if elapsed > SLOW_LOAD_USEC:
		_logger.warn(
			"Blocking load was slow.", {&"path": key, &"msec": elapsed / 1000.0}
		)

	if resource == null:
		_logger.error("Failed to load resource.", {&"path": key})

	return resource


## request asks for the resource at `path` to be loaded on a thread, and returns the
## handle that reports when it has. A repeat of a request still waiting or in flight
## returns the same handle, whether by `uid://` or by path. An `urgent` request, or an
## urgent repeat of one still waiting, starts next; nothing interrupts the request in
## flight, which the engine cannot cancel.
##
## NOTE: There is no way to withdraw a request. One nobody wants any more costs only
## background time, and its resource is freed with its last handle.
static func request(
	path: String, type_hint: String = "", urgent: bool = false
) -> Result:
	var key := _to_key(path)

	var existing: Result = _results.get(key)
	if existing:
		if urgent and existing in _queue:
			_queue.erase(existing)
			_queue.push_front(existing)

		return existing

	var result := Result.new()
	result.path = key
	result._type_hint = type_hint

	if _backend.has_cached(key):
		result.resource = _backend.get_cached(key)
		result.status = (
			ResourceLoader.THREAD_LOAD_LOADED
			if result.resource
			else ResourceLoader.THREAD_LOAD_FAILED
		)
		return result

	_results[key] = result

	if urgent:
		_queue.push_front(result)
	else:
		_queue.append(result)

	_connect_step()

	return result


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _connect_step runs the step on every frame while there is work.
static func _connect_step() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and not tree.process_frame.is_connected(_step):
		_last_step_usec = -1
		tree.process_frame.connect(_step)


## _disconnect_step stops running the step.
static func _disconnect_step() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.process_frame.is_connected(_step):
		tree.process_frame.disconnect(_step)


## _finish ends the request with the given outcome and reports it. `context` adds to
## what a failure logs.
static func _finish(
	result: Result, resource: Resource, context: Dictionary = {}
) -> void:
	_results.erase(result.path)

	result.resource = resource
	result.status = (
		ResourceLoader.THREAD_LOAD_LOADED
		if resource
		else ResourceLoader.THREAD_LOAD_FAILED
	)

	if resource:
		_logger.debug("Loaded resource.", {&"path": result.path})
	else:
		context[&"path"] = result.path
		_logger.error("Failed to load resource.", context)

	result.done.emit()


## _finish_in_flight ends the request in flight if the engine reports it ended, and
## otherwise watches it for a stall.
static func _finish_in_flight(frame_usec: int) -> void:
	var result := _in_flight

	if result._fetched:
		_in_flight = null
		_finish(result, result.resource)
		return

	var progress: Array = []
	var status := _backend.get_progress(result.path, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_watch_stall(progress[0] if not progress.is_empty() else 0.0, frame_usec)
		return

	_in_flight = null

	var resource: Resource = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		resource = _backend.get_threaded(result.path)

	_finish(result, resource)


## _reset forgets every request and restores the engine's loader. Only tests call this,
## between cases, since the loader's state outlives a scene.
static func _reset() -> void:
	_disconnect_step()

	_backend = Backend.new()
	_in_flight = null
	_last_step_usec = -1
	_queue.clear()
	_results.clear()
	_stall_progress = -1.0
	_stall_reported = false
	_stall_usec = 0


## _set_backend replaces the engine's loader, which a test does to script it.
static func _set_backend(backend: Backend) -> void:
	assert(backend is Backend, "invalid argument; missing backend")
	_backend = backend


## _start_next starts the next waiting request, failing any the engine refuses.
static func _start_next() -> void:
	while _in_flight == null and not _queue.is_empty():
		var result: Result = _queue.pop_front()

		var err := _backend.start(result.path, result._type_hint)
		if err != OK:
			_finish(result, null, {&"error": err})
			continue

		_logger.debug("Loading resource.", {&"path": result.path})

		_in_flight = result
		_stall_progress = -1.0
		_stall_reported = false
		_stall_usec = 0


## _step finishes the request in flight if it ended, finishes every waiting request
## whose resource is already cached, then starts the next one.
static func _step() -> void:
	var now := _backend.get_ticks_usec()
	var frame_usec := 0 if _last_step_usec < 0 else now - _last_step_usec
	_last_step_usec = now

	if _in_flight:
		_finish_in_flight(frame_usec)

	# NOTE: A report can run code that changes the queue, so each waiting request is
	# looked up again before it is finished.
	for result in _queue.duplicate():
		if result in _queue and _backend.has_cached(result.path):
			_queue.erase(result)
			_finish(result, _backend.get_cached(result.path))

	_start_next()

	if _in_flight == null and _queue.is_empty():
		_disconnect_step()


## _to_key returns the path a request is known by, a `uid://` resolved to its file.
static func _to_key(path: String) -> String:
	assert(path, "invalid argument; missing path")

	var resolved := ResourceUID.ensure_path(path)
	return resolved if resolved else path


## _watch_stall reports, once, a request in flight whose progress hasn't moved for
## `STALL_USEC` of frame time.
static func _watch_stall(progress: float, frame_usec: int) -> void:
	if progress != _stall_progress:
		_stall_progress = progress
		_stall_usec = 0
		return

	_stall_usec += mini(frame_usec, STALL_FRAME_USEC)

	if _stall_usec < STALL_USEC or _stall_reported:
		return

	_stall_reported = true

	var queued := PackedStringArray()
	for result in _queue:
		queued.append(result.path)

	(
		_logger
		. error(
			"Threaded load made no progress.",
			{&"path": _in_flight.path, &"queued": ",".join(queued)},
		)
	)
