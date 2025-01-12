##
## std/save/file.gd
##
## StdSaveFile is a resource defining a type of save file and how to interact with it.
##

class_name StdSaveFile
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## file_opened is emitted when the underlying save file is first opened and this node is
## considered "loaded".
signal file_opened

## file_closed is emitted when the underlying save file is closed and this node is
## considered "unloaded".
signal file_closed

@warning_ignore("UNUSED_SIGNAL")
## read_begin is emitted when a read of the save file is started.
signal read_begin

@warning_ignore("UNUSED_SIGNAL")
## read_done is emitted when a read of the save file is successfully completed.
signal read_done

@warning_ignore("UNUSED_SIGNAL")
## read_error is emitted when a read of the save file fails.
signal read_error(err: Error)

@warning_ignore("UNUSED_SIGNAL")
## write_begin is emitted when a write to the save file is started.
signal write_begin

@warning_ignore("UNUSED_SIGNAL")
## write_done is emitted when a write to the save file is successfully completed.
signal write_done(checksum: String)

@warning_ignore("UNUSED_SIGNAL")
## read_error is emitted when a write to the save file fails.
signal write_error(err: Error)

# -- CONFIGURATION ------------------------------------------------------------------- #

## path is a save directory-relative path to the specific save file.
@export var path: String = ""

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_open: bool = false
var _logger := StdLogger.create(&"std/save/file")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open loads the save file, making it active and eligible for reading from/writing to.
func open(directory: String) -> Error:
	if path.is_absolute_path():
		assert(false, "invalid config; expected relative path")
		return ERR_FILE_BAD_PATH

	if _is_open:
		return OK

	var err := _open(directory)
	if err != OK:
		(
			_logger
			. error(
				"Failed to open save file.",
				{&"directory": directory, &"error": err, &"path": path},
			)
		)

		return err

	_is_open = true

	_logger.info("Opened save file.", {&"directory": directory, &"path": path})
	file_opened.emit()

	return OK


## is_open returns whether the save file is eligible for reading from/writing to.
func is_open() -> bool:
	return _is_open


## close unloads the save file, making it no longer eligible for reads and writes.
func close() -> void:
	_close()

	_is_open = false

	_logger.info("Closed save file.", {&"path": path})
	file_closed.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _on_enter() -> void:
	_logger = _logger.with({&"path": path})


func _on_exit() -> void:
	if _is_open:
		close()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _close() -> void:
	assert(false, "unimplemented")


func _open(_directory: String) -> Error:
	assert(false, "unimplemented")
	return FAILED
