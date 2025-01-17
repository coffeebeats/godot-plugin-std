##
## std/config/writer/writer.gd
##
## `StdConfigWriter` is a base class for types which synchronize `Config` instances with
## a configured storage file.
##

class_name StdConfigWriter
extends StdFileWriter

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

enum Command { UNSPECIFIED, LOAD, STORE }  # gdlint:ignore=class-definitions-order


class ReadResult:
	var error: Error = ERR_UNCONFIGURED
	var bytes: PackedByteArray = PackedByteArray()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _pending: Command = Command.UNSPECIFIED
var _pending_config: Config = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_filepath returns the target file path at which the configuration data is stored.
func get_filepath() -> String:
	return _get_filepath()


## load_config hydrates the provided 'Config' instance with the contents of the file.
func load_config(config: Config) -> StdThreadWorkerResult:
	assert(config is Config, "invalid argument: expected a 'Config' instance")

	_logger.info("Reading configuration from file.", {&"path": _get_filepath()})

	_worker_mutex.lock()

	if _pending != Command.UNSPECIFIED:
		_worker_mutex.unlock()
		assert(false, "invalid state; worker busy")
		return StdThreadWorkerResult.failed(ERR_ALREADY_IN_USE)

	_pending = Command.LOAD
	_pending_config = config
	_worker_mutex.unlock()

	return run()


## store_config persists the provided 'Config' instance's contents to the file.
func store_config(config: Config) -> StdThreadWorkerResult:
	_logger.info("Storing configuration in file.", {&"path": _get_filepath()})

	_worker_mutex.lock()

	if _pending != Command.UNSPECIFIED:
		_worker_mutex.unlock()
		assert(false, "invalid state; worker busy")
		return StdThreadWorkerResult.failed(ERR_ALREADY_IN_USE)

	_pending = Command.STORE
	_pending_config = config
	_worker_mutex.unlock()

	return run()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _config_read_bytes is an overridable method which defines how the specified file
## contents are read from the provided filepath. This allows customizing things like
## which backup files are used, for example.
##
## By default, this implementation will read directly from the provided file path.
func _config_read_bytes(config_path: String) -> ReadResult:
	var result := ReadResult.new()

	var err := _file_open(config_path, FileAccess.READ)
	if err != OK:
		result.error = err
		return result

	var bytes := _file_read()

	err = _file_close()
	if err != OK:
		assert(false, "invalid state; failed to close file")
		result.error = err
		return result

	result.bytes = bytes
	result.error = OK

	return result


## _config_write_bytes is an overridable method which defines how the specified file
## contents are written to the provided filepath. This allows customizing things like
## which backup files are used, for example.
##
## By default, this implementation will write the provided file contents to a '.tmp'
## file. Once that succeeds, the file will be renamed to the actual file. This ensures
## the target filepath is only overwritten if it was successfully written first.
func _config_write_bytes(config_path: String, data: PackedByteArray) -> Error:
	var tmp_config_path := _get_tmp_filepath()
	var err := _file_open(tmp_config_path, FileAccess.WRITE)
	if err != OK:
		return err

	err = _file_write(data)
	if err != OK:
		assert(false, "invalid state; failed to close file")
		return err  # NOTE: No need to close; only error is file not found.

	err = _file_close()
	if err != OK:
		assert(false, "invalid state; failed to close file")
		return err

	return _file_move(tmp_config_path, config_path)


func _deserialize_var(bytes: PackedByteArray) -> Variant:
	return bytes_to_var(bytes)


func _get_filepath() -> String:
	assert(false, "unimplemented")
	return ""


func _serialize_var(variant: Variant) -> PackedByteArray:
	return var_to_bytes(variant)


func _worker_impl() -> Error:
	_worker_mutex.lock()

	var pending := _pending
	_pending = Command.UNSPECIFIED

	var config := _pending_config
	_pending_config = null

	_worker_mutex.unlock()

	if not config:
		assert(false, "invalid state; missing config")
		return ERR_DOES_NOT_EXIST

	var path := FilePath.make_project_path_absolute(_get_filepath())
	if not path:
		return ERR_FILE_BAD_PATH

	match pending:
		Command.LOAD:
			var read_result := _config_read_bytes(path)
			if read_result.error != OK:
				return read_result.error

			var data: Variant = _deserialize_var(read_result.bytes)
			if not data is Dictionary:
				return ERR_INVALID_DATA

			config.lock()
			config._data = data
			config.unlock()

			return OK

		Command.STORE:
			config.lock()
			var bytes := _serialize_var(config._data)
			config.unlock()

			return _config_write_bytes(path, bytes)

	assert(false, "invalid argument; missing command")
	return ERR_BUG  # gdlint:ignore=max-returns


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_tmp_filepath() -> String:
	return _get_filepath() + ".tmp"
