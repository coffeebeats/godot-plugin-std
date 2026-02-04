##
## router/loader.gd
##
## StdRouterLoader is a background resource loader for route dependencies. Uses Godot's
## threaded resource loading API to asynchronously load resources required by routes.
## Loaded resources are held in memory to keep them cached while routes are active.
##

class_name StdRouterLoader
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## ProcessCallback is an enumeration of supported engine callbacks in which to run
## background loading status checks.
enum ProcessCallback {
	PROCESS_CALLBACK_PHYSICS = 0,
	PROCESS_CALLBACK_IDLE = 1,
}


## Result contains the results of loading the specified resource.
##
## NOTE: The `done` signal is *not* emitted for resources that were already cached. This
## means that `status`/`is_done()` should always be checked before awaiting `done`.
class Result:
	extends RefCounted

	## done is emitted when an asynchronous load completes. Note that this is not
	## emitted for resources that were already cached.
	signal done

	var path: String
	var scene: PackedScene
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS

	## new_with_path returns a new 'Result' for the resource specified by 'input'.
	static func new_with_path(input: String) -> Result:
		assert(input != "", "missing argument: input")

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


const _TYPE_HINT_PACKED_SCENE := "PackedScene"

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

static var _logger := StdLogger.create(&"std/scene/loader")  # gdlint:ignore=class-definitions-order

var _loading: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_all loads each of the provided packed scene files in the background and returns
## a list of result handlers; these can be used to track the progress of the request.
func load_all(deps: StdRouteDependencies) -> Array[Result]:
	var out: Array[Result] = []

	for resource_path in deps.resources:
		out.append(self.load(resource_path))

	return out


## load loads the provided packed scene file in the background and returns a handle to
## track the progress of the request and access the loaded resource.
func load(path: String) -> Result:
	assert(path.begins_with("res://"), "expected path to be absolute")
	assert(
		path.ends_with(".tscn") or path.ends_with(".scn"),
		"expected path to be a packed scene"
	)

	var is_loading: bool = path in _loading
	if is_loading:
		return _loading[path]

	if ResourceLoader.has_cached(path):
		_logger.info("Returning cached scene file.", {&"path": path})

		var result := Result.new_with_path(path)
		result.path = path
		result.status = ResourceLoader.THREAD_LOAD_LOADED
		result.scene = ResourceLoader.load(path, "PackedScene")

		return result

	_logger.info("Loading scene file.", {&"path": path})

	# FIXME(https://github.com/godotengine/godot/issues/84012): Re-enable
	# 'use_sub_threads' once crashing is resolved.
	assert(not use_sub_threads, "invalid config; not supported")

	var err := ResourceLoader.load_threaded_request(
		path, _TYPE_HINT_PACKED_SCENE, use_sub_threads
	)
	assert(err == OK, "failed to load scene")

	var status := ResourceLoader.load_threaded_get_status(path)
	assert(
		(
			status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
			and status != ResourceLoader.THREAD_LOAD_FAILED
		),
		"failed to load resource"
	)

	if not _loading:
		process_mode = Node.PROCESS_MODE_ALWAYS

	_loading[path] = Result.new_with_path(path)

	return _loading[path]


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	# Trigger the setter to properly configure callback functions.
	process_callback = process_callback

	# Disable processing until a request is made.
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	return _update(delta)


func _process(delta: float) -> void:
	return _update(delta)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update(_delta: float) -> void:
	var completed: Array[Result] = []

	for path in _loading:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue

		var result: Result = _loading[path]
		assert(result != null, "invalid state; missing result")

		result.status = status
		completed.append(result)

	for result in completed:
		if result.status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(result.path)
			assert(scene != null, "loaded scene was unexpectedly null")

			result.scene = scene

		(
			_logger
			. info(
				"Finished loading scene.",
				{&"path": result.path, &"status": result.status},
			)
		)

		_loading.erase(result.path)

		result.done.emit()

	if not _loading:
		process_mode = Node.PROCESS_MODE_DISABLED
