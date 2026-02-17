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

const DISK_BLOCK_SIZE := 4096
const VARIANT_ENCODING_LENGTH_MIN := 4

enum Command { UNSPECIFIED, LOAD, STORE, COPY }  # gdlint:ignore=class-definitions-order


class ReadResult:
	var error: Error = ERR_UNCONFIGURED
	var bytes: PackedByteArray = PackedByteArray()


# -- CONFIGURATION ------------------------------------------------------------------- #

## backup_count controls the number of rolling backup files to maintain.
@export var backup_count: int = 0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _pending: Command = Command.UNSPECIFIED
var _pending_config: Config = null
var _pending_copy_from: String = ""
var _pending_copy_to: String = ""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## copy_file enqueues an asynchronous file copy from `from` to `to` on the worker thread
## (both paths must be absolute). Note that this method enforces that the target disk
## has sufficient space.
func copy_file(
	from: String,
	to: String,
) -> StdThreadWorkerResult:
	(
		_logger
		. info(
			"Copying file.",
			{&"from": from, &"to": to},
		)
	)

	_worker_mutex.lock()

	if _pending != Command.UNSPECIFIED:
		_worker_mutex.unlock()
		return StdThreadWorkerResult.failed(ERR_BUSY)

	_pending = Command.COPY
	_pending_copy_from = from
	_pending_copy_to = to
	_worker_mutex.unlock()

	return run()


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
		return StdThreadWorkerResult.failed(ERR_BUSY)

	_pending = Command.LOAD
	_pending_config = config
	_worker_mutex.unlock()

	return run()


## store_config persists the provided 'Config' instance's contents to the file. Note
## that this method enforces that the target disk has sufficient space.
func store_config(config: Config) -> StdThreadWorkerResult:
	_logger.info("Storing configuration in file.", {&"path": _get_filepath()})

	_worker_mutex.lock()

	if _pending != Command.UNSPECIFIED:
		_worker_mutex.unlock()
		return StdThreadWorkerResult.failed(ERR_BUSY)

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
	return _read_file_bytes(config_path)


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

	_rotate_backups(config_path)

	return _file_move(tmp_config_path, config_path)


func _deserialize_var(bytes: PackedByteArray) -> Variant:
	if bytes.size() < _get_minimum_size():
		return null

	return bytes_to_var(bytes)


func _get_filepath() -> String:
	assert(false, "unimplemented")
	return ""


func _get_minimum_size() -> int:
	return VARIANT_ENCODING_LENGTH_MIN


func _serialize_var(variant: Variant) -> PackedByteArray:
	return var_to_bytes(variant)


func _worker_impl() -> Error:
	_worker_mutex.lock()

	var pending := _pending
	_pending = Command.UNSPECIFIED

	var config := _pending_config
	_pending_config = null

	var copy_from := _pending_copy_from
	_pending_copy_from = ""
	var copy_to := _pending_copy_to
	_pending_copy_to = ""

	_worker_mutex.unlock()

	if pending == Command.COPY:
		return _handle_copy(copy_from, copy_to)

	if not config:
		assert(false, "invalid state; missing config")
		return ERR_DOES_NOT_EXIST

	var filepath := _get_filepath()
	if not filepath:
		return ERR_FILE_BAD_PATH

	var path := FilePath.make_project_path_absolute(filepath)
	if not path:
		return ERR_FILE_BAD_PATH

	match pending:
		Command.LOAD:
			return _handle_load(config, path)
		Command.STORE:
			return _handle_store(config, path)

	assert(false, "invalid argument; missing command")
	return ERR_BUG  # gdlint:ignore=max-returns


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _check_disk_space is a best-effort pre-flight check that returns
## `ERR_FILE_CANT_WRITE` if the disk is too full to write `size` bytes.
##
## NOTE: This method returns `OK` if the directory can't be opened (e.g. it doesn't
## exist yet); the actual write will surface any real errors.
func _check_disk_space(path: String, size: int) -> Error:
	var path_dir := path.get_base_dir()
	var dir := DirAccess.open(path_dir)
	if not dir:
		return OK

	@warning_ignore("integer_division")
	var space_required := (
		(size + DISK_BLOCK_SIZE - 1) / DISK_BLOCK_SIZE * DISK_BLOCK_SIZE
	)

	# NOTE: `space_left` will be `0` on unsupported platforms, so ignore that value.
	var space_left := dir.get_space_left()
	if space_left > 0 and space_left < space_required:
		return ERR_FILE_CANT_WRITE

	return OK


## _get_bak_filepath returns the absolute path to the backup file at the given depth.
func _get_bak_filepath(depth: int = 0) -> String:
	var base := FilePath.make_project_path_absolute(_get_filepath())

	return base + ".bak" if depth <= 0 else base + ".bak%d" % (depth + 1)


## _get_tmp_filepath returns the absolute path to the temporary write file.
func _get_tmp_filepath() -> String:
	return FilePath.make_project_path_absolute(_get_filepath()) + ".tmp"


func _handle_copy(from: String, to: String) -> Error:
	var source := FileAccess.open(from, FileAccess.READ)
	if source:
		var size := source.get_length()
		source.close()
		var disk_err := _check_disk_space(to, size)
		if disk_err != OK:
			(
				_logger
				. error(
					"Not enough disk space to copy file.",
					{&"path": to, &"error": disk_err},
				)
			)
			return disk_err

	return _file_copy(from, to)


func _handle_load(
	config: Config,
	path: String,
) -> Error:
	var read_result := _config_read_bytes(path)

	var modified_time := FileAccess.get_modified_time(path)
	(
		_logger
		. debug(
			"Read config bytes from file.",
			{
				&"error": read_result.error,
				&"modified":
				(
					Time.get_date_string_from_unix_time(modified_time)
					if modified_time
					else ""
				),
				&"path": path,
				&"size": read_result.bytes.size(),
			},
		)
	)

	var data: Variant = null
	if read_result.error == OK and read_result.bytes.size() >= _get_minimum_size():
		data = _deserialize_var(read_result.bytes)

	# Backup fallback: try backups if main file was corrupt or missing.
	if (
		not data is Dictionary
		and backup_count > 0
		and read_result.error in [OK, ERR_FILE_NOT_FOUND]
	):
		for i in range(backup_count):
			var path_bak := _get_bak_filepath(i)

			if not FileAccess.file_exists(path_bak):
				continue

			var read_bak_result := _read_file_bytes(path_bak)
			if read_bak_result.error != OK:
				continue

			if read_bak_result.bytes.size() < _get_minimum_size():
				continue

			data = _deserialize_var(read_bak_result.bytes)
			if data is Dictionary:
				var copy_err := _file_copy(path_bak, path)
				if copy_err != OK:
					(
						_logger
						. warn(
							"Failed to restore main file from backup.",
							{&"error": copy_err, &"path": path_bak},
						)
					)
				break

	# If data recovered from any source, use it.
	if data is Dictionary:
		config.lock()
		config._data = data
		config.unlock()

		return OK

	# No data recovered.
	if read_result.error != OK:
		return read_result.error

	return ERR_INVALID_DATA


func _handle_store(
	config: Config,
	path: String,
) -> Error:
	config.lock()
	var bytes := _serialize_var(config._data)
	config.unlock()

	var disk_err := _check_disk_space(path, bytes.size())
	if disk_err != OK:
		(
			_logger
			. error(
				"Not enough disk space to write file.",
				{&"path": path, &"error": disk_err},
			)
		)
		return disk_err

	var err := _config_write_bytes(path, bytes)

	(
		_logger
		. debug(
			"Stored config bytes to file.",
			{&"error": err, &"path": path, &"size": bytes.size()},
		)
	)

	return err


## _read_file_bytes reads the raw contents from the specified file path using managed
## file I/O (logging, state tracking). Unlike `_config_read_bytes`, this method is not
## virtual and should be used for direct file reads (e.g. backup reads).
func _read_file_bytes(file_path: String) -> ReadResult:
	var result := ReadResult.new()

	var err := _file_open(file_path, FileAccess.READ, false)
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


## _rotate_backups shifts rolling backups and copies the current file to `.bak`.
func _rotate_backups(config_path: String) -> void:
	if backup_count <= 0 or not FileAccess.file_exists(config_path):
		return

	var path_oldest := _get_bak_filepath(backup_count - 1)
	var path_oldest_tmp := path_oldest + ".tmp"

	# Clean up orphaned .tmp from a previous failed rotation.
	_file_delete(path_oldest_tmp)

	if FileAccess.file_exists(path_oldest):
		_file_move(path_oldest, path_oldest_tmp)

	# Shift each backup up: .bak{N-1} -> .bak{N}
	for i in range(backup_count - 1, 0, -1):
		var from := _get_bak_filepath(i - 1)
		var to := _get_bak_filepath(i)

		if FileAccess.file_exists(from):
			_file_move(from, to)

	# Back up current file: .bak (depth 0).
	var bak := _get_bak_filepath(0)

	var copy_err := _file_copy(config_path, bak)
	if copy_err != OK:
		(
			_logger
			. warn(
				"Backup rotation failed; rolling back.",
				{&"error": copy_err, &"path": config_path},
			)
		)

		# Reverse the shifts: move .bak{i} -> .bak{i-1} for each shifted file.
		for i in range(1, backup_count):
			var from := _get_bak_filepath(i)
			var to := _get_bak_filepath(i - 1)

			if FileAccess.file_exists(from):
				_file_move(from, to)

		if FileAccess.file_exists(path_oldest_tmp):
			_file_move(path_oldest_tmp, path_oldest)

		return

	_file_delete(path_oldest_tmp)
