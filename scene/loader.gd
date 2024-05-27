##
## std/scene/loader.gd
##
## Loader is a node which can load packed scenes using background threads.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

signal scene_loaded(path: String, packed_scene: PackedScene)

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TYPE_HINT_PACKED_SCENE := "PackedScene"


class Result:
	extends RefCounted

	signal done

	var _path: String
	var _packed_scene: PackedScene
	var _status: ResourceLoader.ThreadLoadStatus = (
		ResourceLoader.THREAD_LOAD_IN_PROGRESS
	)

	static func new_with_path(path: String) -> Result:
		assert(path != "", "missing argument: path")

		var result := Result.new()
		result._path = path

		return result

	func get_path() -> String:
		return _path

	func get_status() -> int:
		return _status

	func get_packed_scene() -> PackedScene:
		return null

	func _set_packed_scene(packed_scene: PackedScene) -> void:
		assert(packed_scene != null, "missing input: packed_scene")
		assert(_packed_scene == null, "result already set")

		_packed_scene = packed_scene
		done.emit()

	func _set_status(status: ResourceLoader.ThreadLoadStatus) -> void:
		_status = status


# -- CONFIGURATION ------------------------------------------------------------------- #

# -- INITIALIZATION ------------------------------------------------------------------ #

var _to_load: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func load_scene(path: String, use_sub_threads: bool = true) -> Result:
	assert(path.begins_with("res://"), "expected path to be absolute")
	assert(
		path.ends_with(".tscn") or path.ends_with(".scn"),
		"expected path to be a packed scene"
	)

	print("loader.gd: ", "loading scene file: ", path)

	var is_loading: bool = path in _to_load
	if is_loading:
		return _to_load[path]

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

	var result := Result.new_with_path(path)

	_to_load[path] = result

	return result


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float):
	var completed := PackedStringArray()

	for path in _to_load:
		var result: Result = _to_load[path]
		assert(result != null, "invalid state; missing result")

		var status := ResourceLoader.load_threaded_get_status(path)
		assert(
			(
				status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
				and status != ResourceLoader.THREAD_LOAD_FAILED
			),
			"failed to load resource"
		)

		result._set_status(status)  # gdlint:ignore=private-method-call

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			completed.append(path)

	for path in completed:
		var result: Result = _to_load[path]
		assert(result != null, "invalid state; missing result")

		var packed_scene: PackedScene = ResourceLoader.load_threaded_get(path)
		assert(packed_scene != null, "loaded scene was unexpectedly null")

		result._set_packed_scene(packed_scene)  # gdlint:ignore=private-method-call
		scene_loaded.emit(path, packed_scene)

		print("loader.gd: ", "finished loading scene: ", path)

		_to_load.erase(path)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _publish_loaded_scene(path: String):
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(path)
	assert(packed_scene != null, "loaded scene was unexpectedly null")

	scene_loaded.emit(path, packed_scene)

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
