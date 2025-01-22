##
## std/save/file.gd
##
## StdSaveFile is a node which can read from and write to save files in a background
## thread. Only one save file can be interacted with at a time.
##

class_name StdSaveFile
extends StdConfigWriterBinary

# -- SIGNALS ------------------------------------------------------------------------- #

## save_loaded is emitted when a call to load save data completes, regardless of the
## outcome. Check the `status` argument to determine whether the operation succeeded.
signal save_loaded(data: StdSaveData, status: Status)

# save_stored is emitted when a call to store save data completes, regardless of the
## outcome. Check the `status` argument to determine whether the operation succeeded.
signal save_stored(data: StdSaveData, status: Status)

# -- DEFINITIONS --------------------------------------------------------------------- #

## Status defines the possible states that a save slot can be in.
enum Status {
	UNKNOWN = 0,
	OK = 1,
	EMPTY = 2,
	BROKEN = 3,
}

const STATUS_BROKEN := Status.BROKEN
const STATUS_EMPTY := Status.EMPTY
const STATUS_OK := Status.OK
const STATUS_UNKNOWN := Status.UNKNOWN

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_save_data asynchronously hydrates the provided save data resource with the save
## data persisted at this writer's configured filepath. The return value denotes the
## current state of the save slot (i.e. whether it's empty, usable, or corrupt).
##
## NOTE: The results of this function call must be awaited.
func load_save_data(data: StdSaveData) -> Status:
	assert(data is StdSaveData, "invalid argument; missing data")

	var config := Config.new()  # Will temporarily hold save data.

	var result: Result = load_config(config)
	assert(result is Result, "invalid state; missing result")

	var err: Error = await result.done
	if err == OK:
		data.reset()
		data.load(config)

	var status := _handle_result(err)
	save_loaded.emit(data, status)

	return status


## load_save_data_sync synchronously hydrates the provided save data resource with the
## save data persisted at this writer's configured filepath. The return value denotes
## the current state of the save slot (i.e. whether it's empty, usable, or corrupt).
func load_save_data_sync(data: StdSaveData) -> Status:
	assert(data is StdSaveData, "invalid argument; missing data")

	var config := Config.new()  # Will temporarily hold save data.

	var result: Result = load_config(config)
	assert(result is Result, "invalid state; missing result")

	var err: Error = result.wait()
	if err == OK:
		data.reset()
		data.load(config)

	var status := _handle_result(err)
	save_loaded.emit(data, status)

	return status


## store_save_data asynchronously persists the provided save data to this writer's
## configured filepath. The return value denotes the current state of the save slot
## (i.e. whether it's empty, usable, or corrupt).
##
## NOTE: The results of this function call must be awaited.
func store_save_data(data: StdSaveData) -> Status:
	assert(data is StdSaveData, "invalid argument; missing data")

	var config := Config.new()  # Will temporarily hold save data.
	data.store(config)

	var result: Result = store_config(config)
	assert(result is Result, "invalid state; missing result")

	var err: Error = await result.done

	var status := _handle_result(err)
	save_stored.emit(data, status)

	return status


## store_save_data_sync synchronously persists the provided save data to this writer's
## configured filepath. The return value denotes the current state of the save slot
## (i.e. whether it's empty, usable, or corrupt).
func store_save_data_sync(data: StdSaveData) -> Status:
	assert(data is StdSaveData, "invalid argument; missing data")

	var config := Config.new()  # Will temporarily hold save data.
	data.store(config)

	var result: Result = store_config(config)
	assert(result is Result, "invalid state; missing result")

	var err: Error = await result.done

	var status := _handle_result(err)
	save_stored.emit(data, status)

	return status


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _on_enter() -> void:
	_logger = _logger.named(&"std/save/file")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_filepath() -> String:
	var path_rel := path.trim_prefix("save://")
	assert(not path_rel.is_absolute_path(), "invalid argument; expected relative path")

	var directory := _get_save_directory()
	if not directory:
		return ""

	return directory.path_join(path_rel)


func _get_save_directory() -> String:
	assert(false, "unimplemented")
	return ""


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _is_save_directory_empty() -> bool:
	var directory := _get_save_directory()
	if not directory:
		assert(false, "invalid state; missing directory")
		return false

	var path_directory := FilePath.make_project_path_absolute(directory)

	# If the save directory is empty, then it's safe to consider slot empty.
	if (
		not DirAccess.dir_exists_absolute(path_directory)
		or DirAccess.get_files_at(path_directory).is_empty()
	):
		return true

	return false


func _handle_result(err: Error) -> Status:
	match err:
		OK:
			return STATUS_OK

		ERR_FILE_NOT_FOUND:
			return STATUS_EMPTY if _is_save_directory_empty() else STATUS_BROKEN

		ERR_INVALID_DATA:
			return STATUS_BROKEN

		_:
			assert(false, "encountered unknown error")
			(
				_logger
				. warn(
					"Encountered unknown error when reading save file.",
					{&"error": err},
				)
			)

			return STATUS_UNKNOWN
