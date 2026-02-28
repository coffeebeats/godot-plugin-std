##
## screen/loader.gd
##
## StdScreenLoader is a background resource loader for screen scenes. Uses Godot's
## threaded resource loading API to asynchronously load packed scene resources. Loaded
## resources are held in memory to keep them cached while screens are active.
##

class_name StdScreenLoader
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TYPE_HINT_PACKED_SCENE := "PackedScene"

## ProcessCallback is an enumeration of supported engine callbacks in which to run
## background loading status checks.
enum ProcessCallback {  # gdlint:ignore=class-definitions-order
	PROCESS_CALLBACK_PHYSICS = 0,
	PROCESS_CALLBACK_IDLE = 1,
}


## Result contains the results of loading the specified resource.
##
## NOTE: The `done` signal is always emitted, including for cached resources, but cached
## results emit it via `call_deferred` so callers have time to connect.
class Result:
	extends RefCounted

	## done is emitted when a load completes (including cached results via
	## call_deferred). Callers can always await this signal.
	signal done

	var path: String
	var scene: PackedScene
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS

	## new_with_path returns a new 'Result' for the resource at 'input'.
	static func new_with_path(input: String) -> Result:
		if not input:
			assert(false, "missing argument: input")
			return null

		var result := Result.new()
		result.path = input

		return result

	## get_error returns the error status for the 'Result'.
	func get_error() -> Error:
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return ERR_INVALID_PARAMETER
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			return FAILED

		return OK

	## is_done returns when the load request has completed. Note that this does *not*
	## imply success, only that processing has completed.
	func is_done() -> bool:
		return status != ResourceLoader.THREAD_LOAD_IN_PROGRESS


# -- CONFIGURATION ------------------------------------------------------------------- #

## process_callback determines whether 'update' is called during the physics or idle
## process callback function (if the process mode allows for it).
@export var process_callback := ProcessCallback.PROCESS_CALLBACK_PHYSICS:
	set(value):
		process_callback = value

		match value:
			ProcessCallback.PROCESS_CALLBACK_PHYSICS:
				set_physics_process(true)
				set_process(false)
			ProcessCallback.PROCESS_CALLBACK_IDLE:
				set_physics_process(false)
				set_process(true)

## use_sub_threads controls whether sub threads are used during background loading.
##
## NOTE: Disabling this may reduce noisy errors when loaded scripts contain references
## to autoloaded scenes (see https://github.com/godotengine/godot/issues/98865).
##
## FIXME(https://github.com/godotengine/godot/issues/84012): Re-enable 'use_sub_threads'
## once crashing is resolved.
@export var use_sub_threads: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/screen/loader")  # gdlint:ignore=class-definitions-order,max-line-length

var _loading: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_all_scenes loads each of the provided packed scene files in the background and
## returns a list of result handles; these can be used to track the progress of each
## request.
func load_all_scenes(paths: PackedStringArray) -> Dictionary[String, Result]:
	var out: Dictionary[String, Result] = {}

	for resource_path in paths:
		out[resource_path] = load_scene(resource_path)

	return out


## load_scene loads the provided packed scene file in the background and returns a
## handle to track the progress of the request and access the loaded resource.
func load_scene(path: String) -> Result:
	assert(
		path.begins_with("res://") or path.begins_with("uid://"),
		"expected path to be absolute or a UID",
	)

	var is_loading: bool = path in _loading
	if is_loading:
		return _loading[path]

	if ResourceLoader.has_cached(path):
		_logger.info("Returning cached scene file.", {&"path": path})

		var result := Result.new_with_path(path)
		result.scene = ResourceLoader.load(path, "PackedScene")

		if result.scene == null:
			_logger.error("Cached scene was null.", {&"path": path})
			result.status = ResourceLoader.THREAD_LOAD_FAILED
		else:
			result.status = ResourceLoader.THREAD_LOAD_LOADED

		result.done.emit.call_deferred()

		return result

	_logger.info("Loading scene file.", {&"path": path})

	# FIXME(https://github.com/godotengine/godot/issues/84012): Re-enable
	# 'use_sub_threads' once crashing is resolved.
	assert(not use_sub_threads, "invalid config; not supported")

	var err := ResourceLoader.load_threaded_request(
		path, _TYPE_HINT_PACKED_SCENE, use_sub_threads
	)

	if err != OK:
		(
			_logger
			. error(
				"Failed to request threaded load.",
				{&"path": path, &"error": err},
			)
		)

		var result := Result.new_with_path(path)
		result.status = ResourceLoader.THREAD_LOAD_FAILED
		result.done.emit.call_deferred()
		return result

	var status := ResourceLoader.load_threaded_get_status(path)

	if (
		status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		or status == ResourceLoader.THREAD_LOAD_FAILED
	):
		(
			_logger
			. error(
				"Threaded load failed immediately.",
				{&"path": path, &"status": status},
			)
		)

		var result := Result.new_with_path(path)
		result.status = status
		result.done.emit.call_deferred()
		return result

	if not _loading:
		process_mode = Node.PROCESS_MODE_ALWAYS

	_loading[path] = Result.new_with_path(path)

	return _loading[path]


## load_scene_sync blocks the calling thread until the load at `path` finishes, then
## returns the loaded `PackedScene`. The path is removed from the internal loading
## tracker so that `_update` does not double-process it. Only call this for paths that
## are actively tracked.
func load_scene_sync(path: String) -> PackedScene:
	assert(path in _loading, "path not being loaded")

	var result: Result = _loading[path]

	if not result.is_done():
		result.scene = ResourceLoader.load_threaded_get(path)

		if result.scene == null:
			_logger.error("Synchronous load returned null.", {&"path": path})
			result.status = ResourceLoader.THREAD_LOAD_FAILED
		else:
			result.status = ResourceLoader.THREAD_LOAD_LOADED

	_loading.erase(path)

	if not _loading:
		process_mode = Node.PROCESS_MODE_DISABLED

	return result.scene


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	process_callback = process_callback
	process_mode = Node.PROCESS_MODE_DISABLED  # Disable until a request is made.


func _physics_process(delta: float) -> void:
	return _update(delta)


func _process(delta: float) -> void:
	return _update(delta)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update(_delta: float) -> void:
	var done: Array[Result] = []

	for path in _loading:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue

		var result: Result = _loading[path]
		assert(result != null, "invalid state; missing result")

		result.status = status
		done.append(result)

	for result in done:
		if result.status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(result.path)

			if scene == null:
				_logger.error("Loaded scene was null.", {&"path": result.path})
				result.status = ResourceLoader.THREAD_LOAD_FAILED
			else:
				result.scene = scene
				_logger.info("Loaded scene.", {&"path": result.path})
		else:
			(
				_logger
				. error(
					"Failed to load scene.",
					{
						&"path": result.path,
						&"status": result.status,
					},
				)
			)

		_loading.erase(result.path)

		result.done.emit()

	if not _loading:
		process_mode = Node.PROCESS_MODE_DISABLED
