##
## std/scene/loader.gd
##
## Loader provides the ability to load scene files in the background.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TYPE_HINT_PACKED_SCENE := "PackedScene"

## SceneProcessCallback is an enumeration of supported engine callbacks in which to run
## background loading status checks.
enum SceneProcessCallback {
	SCENE_PROCESS_PHYSICS = 0,
	SCENE_PROCESS_IDLE = 1,
}

## Result contains the results of loading the specified resource.
class Result:
	extends RefCounted

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

# -- CONFIGURATION ------------------------------------------------------------------- #

## process_callback determines whether 'update' is called during the physics or idle
## process callback function (if the process mode allows for it).
@export var process_callback := SceneProcessCallback.SCENE_PROCESS_PHYSICS:
	set(value):
		process_callback = value

		match value:
			SceneProcessCallback.SCENE_PROCESS_PHYSICS:
				set_physics_process(true)
				set_process(false)
			SceneProcessCallback.SCENE_PROCESS_IDLE:
				set_physics_process(false)
				set_process(true)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _loading: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #

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
		print(
			"std/scene/loader.gd[",
			get_instance_id(),
			"]: returning cached scene file: ",
			path
		)

		var result := Result.new_with_path(path)
		result.path = path
		result.status = ResourceLoader.THREAD_LOAD_LOADED
		result.scene = ResourceLoader.load(path, "PackedScene")

		return result

	print("std/scene/loader.gd[", get_instance_id(), "]: loading scene file: ", path)

	var err := ResourceLoader.load_threaded_request(path, _TYPE_HINT_PACKED_SCENE, true)
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

		print(
			"std/scene/loader.gd[",
			get_instance_id(),
			"]: finished loading scene: ",
			result.path
		)

		_loading.erase(result.path)

		result.done.emit()

	if not _loading:
		process_mode = Node.PROCESS_MODE_DISABLED
