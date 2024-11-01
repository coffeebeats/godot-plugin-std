##
## std/config/file.gd
##
## TODO(#42): Refactor this to be a separate node, enabling debounced writes.
##
## ConfigWithFileSync is a Config instance which synchronously updates a provided file
## with changes.
##
## [1] https://github.com/godotengine/godot/issues/80562.
##

extends "config.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("config.gd")
const ConfigWithFileSync := preload("file.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

# -- INITIALIZATION ------------------------------------------------------------------ #

var _file: FileAccess = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## sync_to_file causes this 'Config' to synchronize all of its data to the file located
## at 'path'. If the provided filepath does not exist, it will be created. In addition,
## upon first open, the contents of this 'Config' will be replaced with those in the
## file. Subsequent updates to 'Config' will be persisted to that file.
static func sync_to_file(path: String) -> ConfigWithFileSync:
	assert(path != "", "missing argument: path")
	assert(path.ends_with(".dat"), "invalid argument: past must end with '.dat'")

	var path_absolute: String = path

	if path.begins_with("res://") or path.begins_with("user://"):
		path_absolute = ProjectSettings.globalize_path(path)
	elif not path.begins_with("/"):
		path_absolute = OS.get_executable_path().get_base_dir().path_join(path)

	assert(path_absolute.begins_with("/"), "invalid argument: path")

	if not DirAccess.dir_exists_absolute(path_absolute.get_base_dir()):
		var err := DirAccess.make_dir_recursive_absolute(path_absolute.get_base_dir())
		if err != OK:
			assert(err == OK, "failed to create directory: %d" % err)
			return null

	if not FileAccess.file_exists(path_absolute):
		if FileAccess.open(path_absolute, FileAccess.WRITE) == null:
			var err := FileAccess.get_open_error()
			if err != OK:
				assert(err == OK, "failed to create file: %d" % err)
				return null

	var file := FileAccess.open(path_absolute, FileAccess.READ_WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		if err != OK:
			assert(err == OK, "failed to open file: %d" % err)
			return null

	var bytes := file.get_buffer(file.get_length())

	var data: Variant = bytes_to_var(bytes) if bytes else {}
	if data is not Dictionary:
		assert(
			data is Dictionary,
			(
				"invalid file contents type: %s" % data.get_class()
				if data != null
				else "null"
			),
		)

		return null

	var config := new()

	config._file = file
	config._data = data

	return config


## close closes the underlying file handle and prevents further updates.
func close() -> void:
	if _file:
		_file.close()
		_file = null


## erase clears the value associated with the 'key' in 'category.
func erase(category: StringName, key: StringName) -> bool:
	if not _file:
		assert(_file != null, "invalid state: missing file")
		return false

	var was_updated := _delete_key(category, key, false)
	if was_updated:
		_write_data_to_file()
		changed.emit(category, key)

	return was_updated


## get_path_absolute returns the absolute path to the file in which 'Config' data is
## being synchronized.
func get_path_absolute() -> String:
	if not _file:
		assert(_file != null, "invalid state: missing file")
		return ""

	return _file.get_path_absolute()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_variant(category: StringName, key: StringName) -> Variant:
	if not _file:
		assert(_file != null, "invalid state: missing file")
		return false

	var value: Variant = super._get_variant(category, key)

	return value


func _set_variant(
	category: StringName,
	key: StringName,
	value: Variant,
	emit: bool = true,
) -> bool:
	if not _file:
		assert(_file != null, "invalid state: missing file")
		return false

	var was_updated := super._set_variant(category, key, value, false)
	if was_updated:
		_write_data_to_file()

		if emit:
			changed.emit(category, key)

	return was_updated


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _write_data_to_file(flush: bool = true) -> void:
	if not _file:
		assert(_file != null, "invalid state: missing file")
		return

	_file.seek(0)
	_file.store_buffer(var_to_bytes(_data))

	if flush:
		_file.flush()

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
