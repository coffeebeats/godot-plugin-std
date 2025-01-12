##
## std/save/file_config.gd
##
## StdSaveFileConfig is a save file which stores data in a `Config` instance and writes
## it to a binary file stored at a configured path.
##

class_name StdSaveFileConfig
extends StdSaveFile

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const FILE_READ_CHUNK_SIZE := 1024

# -- INITIALIZATION ------------------------------------------------------------------ #

var _writer: StdBinaryConfigWriter = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_config_data reads save data and hydrates the provided `Config` object with it.
func load_config_data(config: Config) -> Error:
	if not _is_open:
		assert(false, "invalid state; file isn't open")
		return ERR_UNAVAILABLE

	if not _writer:
		assert(false, "invalid state; missing writer node")
		return ERR_UNAVAILABLE

	read_begin.emit()

	# TODO: Make this asynchronous and utilize a background thread for writes.
	var err := _writer.load_config(config)
	if err != OK:
		_logger.error("Failed to load save file data.", {&"error": err, &"path": path})
		read_error.emit(err)
		return err

	read_done.emit()

	return OK


## store_config_data overwrites the stored save data using the provided `Config` object.
func store_config_data(config: Config) -> Error:
	if not _is_open:
		assert(false, "invalid state; file isn't open")
		return ERR_UNAVAILABLE

	if not _writer:
		assert(false, "invalid state; missing writer node")
		return ERR_UNAVAILABLE

	write_begin.emit()

	# TODO: Make this asynchronous and utilize a background thread for writes.
	var err := _writer.store_config(config)
	if err != OK:
		_logger.error("Failed to save data to file.", {&"path": path})
		write_error.emit(err)
		return err

	# TODO: Move this operation onto the file writer so it can be synchronized.
	var checksum := _compute_checksum()
	if not checksum:
		_logger.error("Couldn't determine save file checksum.", {&"path": path})
		write_error.emit(ERR_INVALID_DATA)
		return err

	_logger.info("Successfully saved data to file.", {&"path": path})
	write_done.emit(checksum)

	return OK


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _on_exit() -> void:
	if _writer:
		assert(false, "invalid state; found dangling writer")
		_close()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _close() -> void:
	if not _writer:
		assert(false, "invalid state; found dangling writer")
		return
	
	remove_child(_writer)

	_writer.close()
	_writer.free()
	_writer = null


func _open(directory: String) -> Error:
	if _writer:
		assert(false, "invalid state; found dangling writer")
		return ERR_ALREADY_IN_USE

	_writer = StdBinaryConfigWriter.new()
	_writer.path = directory.path_join(path)

	add_child(_writer, false, INTERNAL_MODE_BACK)

	return OK


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _compute_checksum() -> String:
	if not _writer:
		assert(false, "invalid state; save file not open")
		return ""

	var logger := _logger.with({&"file": _writer.path, &"path": path})

	if not FileAccess.file_exists(_writer.path):
		(
			logger
			.error(
				"Failed to open save file for reading.",
				{&"error": ERR_FILE_NOT_FOUND},
			)
		)

		return ""

	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)

	# Open the file to hash.
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var err := FileAccess.get_open_error()
		logger.error("Failed to open save file for reading.", {&"error": err})

		return ""

	while file.get_position() < file.get_length():
		var remaining = file.get_length() - file.get_position()
		var err := ctx.update(file.get_buffer(min(remaining, FILE_READ_CHUNK_SIZE)))
		if err != OK:
			logger.error("Failed to hash file chunk.", {&"error": err})
			return ""

	return ctx.finish().hex_encode()
