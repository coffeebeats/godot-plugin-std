##
## std/file/writer.gd
##
## StdFileWriter is a base class for a node which manages reading from and writing to
## the file system. Only one file may be open for reading/writing at a time.
##
## NOTE: This class extends `StdThreadWorker`; it's expected that the provided methods
## will be invoked from a separate thread.
##

class_name StdFileWriter
extends StdThreadWorker

# -- DEPENDENCIES -------------------------------------------------------------------- #

const FilePath := preload("path.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _file: FileAccess = null
var _logger := StdLogger.create(&"std/file/writer")

# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _file_close() -> Error:
	if not _file is FileAccess:
		assert(false, "invalid state; no file is open")
		return ERR_DOES_NOT_EXIST

	var path := _file.get_path()

	_file.close()
	_file = null

	_logger.debug("Closed file.", {&"path": path})

	return OK


func _file_delete(path: String) -> Error:
	if _file is FileAccess:
		assert(false, "invalid state; cannot delete file while another is open")
		return ERR_ALREADY_IN_USE

	if not path.is_absolute_path():
		assert(false, "invalid argument; expected absolute path")
		return ERR_INVALID_PARAMETER

	if not FileAccess.file_exists(path):
		return OK

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		_logger.error("Failed to delete file.", {&"path": path})

	_logger.debug("Deleted file.", {&"path": path})

	return err


func _file_move(from: String, to: String) -> Error:
	if _file is FileAccess:
		assert(false, "invalid state; cannot move file while another is open")
		return ERR_ALREADY_IN_USE

	var err := DirAccess.rename_absolute(from, to)
	if err != OK:
		(
			_logger
			. error(
				"Failed to move file.",
				{&"path_from": from, &"path_to": to},
			)
		)

	_logger.debug("Moved file.", {&"path_from": from, &"path_to": to})

	return err


func _file_open(path: String, mode: FileAccess.ModeFlags) -> Error:
	if not path.is_absolute_path():
		assert(false, "invalid argument; expected absolute path")
		return ERR_INVALID_PARAMETER

	if _file is FileAccess:
		assert(false, "invalid state; cannot open file while another is open")
		return ERR_ALREADY_IN_USE

	var logger := _logger.with({&"path": path})

	var path_base_dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(path_base_dir):
		var err := DirAccess.make_dir_recursive_absolute(path_base_dir)
		if err != OK:
			(
				logger
				. error(
					"Failed to make containing directory.",
					{&"directory": path_base_dir},
				)
			)

			return err

	logger = logger.with({&"mode": mode})

	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			var err := FileAccess.get_open_error()
			if err != OK:
				logger.error("Failed to create file.")
				return err

		logger.debug("Created file.")

		file.close()

	_file = FileAccess.open(path, mode)
	if _file == null:
		var err := FileAccess.get_open_error()
		if err != OK:
			logger.error("Failed to open file.")
			return err

	logger.debug("Opened file.")

	return OK


func _file_read(position: int = 0, count: int = -1) -> PackedByteArray:
	if not _file is FileAccess:
		assert(false, "invalid state; no file found")
		return PackedByteArray()

	_file.seek(position)

	var length := (_file.get_length() - position) if count < 0 else count

	return _file.get_buffer(length)


func _file_write(
	bytes: PackedByteArray, position: int = -1, flush: bool = false
) -> Error:
	if not _file is FileAccess:
		assert(false, "invalid state; no file is open")
		return ERR_DOES_NOT_EXIST

	if position > -1:
		_file.seek(position)

	_file.store_buffer(bytes)

	if flush:
		_file.flush()

	return OK
