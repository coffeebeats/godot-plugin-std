##
## screen/manager/preparation.gd
##
## Preparation is the set of loads one screen needs before it can mount: its scene,
## unless an instance was passed or one is kept, its attachment and dependency scenes,
## and the same for every screen it lists under `dependency_screens`, to any depth. It
## reports once every load has ended, and holds the loaded resources, which keeps them
## cached for as long as it lives.
##
## NOTE: A preparation whose loads were all cached is done when it's created and never
## emits `done`, so check `is_done` before awaiting it.
##

extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## done is emitted once every load has ended, from `StdLoader`'s step.
signal done

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Preparation := preload("preparation.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## _error is `FAILED` when there is no scene to mount, set before any load.
var _error := OK

## _pending counts the loads which haven't ended.
var _pending: int = 0

## _results maps each path to its load.
var _results: Dictionary[String, StdLoader.Result] = {}

## _scene_path is the path of the screen's own scene, or empty if it needs none loaded.
var _scene_path: String = ""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create requests `scene_path`, unless it's empty, and each of `paths`, urgently if
## `urgent`, and returns the preparation tracking them. `scene_path` starts first.
static func create(
	scene_path: String,
	paths: PackedStringArray,
	urgent: bool = false,
) -> RefCounted:
	var preparation := Preparation.new()
	preparation._scene_path = scene_path

	var ordered := PackedStringArray()
	if scene_path:
		ordered.append(scene_path)

	for path in paths:
		if path and path not in ordered:
			ordered.append(path)

	# NOTE: An urgent request goes to the front of the loader's queue, so they are made
	# in reverse to start in order.
	if urgent:
		ordered.reverse()

	for path in ordered:
		var result := StdLoader.request(path, "", urgent)
		preparation._results[path] = result

		# NOTE: Two spellings of one file, such as `uid://` and `res://`, share a result,
		# which is counted and connected once.
		if result.is_done() or result.done.is_connected(preparation._on_result_done):
			continue

		preparation._pending += 1
		result.done.connect(preparation._on_result_done, CONNECT_ONE_SHOT)

	return preparation


## failed returns a preparation for a screen with nothing to mount, which is done and
## reports `FAILED`.
static func failed() -> RefCounted:
	var preparation := Preparation.new()
	preparation._error = FAILED
	return preparation


## get_error returns `FAILED` if there's no scene to mount, because the screen's own
## scene failed to load or there was none to load, and `OK` otherwise. A dependency that
## failed to load is reported where it is used.
func get_error() -> Error:
	if _error != OK:
		return _error

	if _scene_path:
		var result: StdLoader.Result = _results.get(_scene_path)
		if result.is_done() and not result.resource is PackedScene:
			return FAILED

	return OK


## get_resource returns the loaded resource at `path`, or null if `path` isn't part of
## this preparation or failed to load.
func get_resource(path: String) -> Resource:
	var result: StdLoader.Result = _results.get(path)
	return result.resource if result else null


## get_scene returns the screen's own loaded scene, or null if it needs none loaded or
## it failed to load.
func get_scene() -> PackedScene:
	return get_resource(_scene_path) as PackedScene if _scene_path else null


## is_done returns whether every load has ended, which doesn't imply success.
func is_done() -> bool:
	return _pending == 0


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_result_done() -> void:
	_pending -= 1

	if _pending == 0:
		done.emit()
