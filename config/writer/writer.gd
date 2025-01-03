##
## std/config/writer/writer.gd
##
## `StdConfigWriter` is a base class for types which synchronize `Config` instances with
## a configured storage file.
##

class_name StdConfigWriter
extends StdFileSyncer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _connected: Config = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_config hydrates the provided 'Config' instance with the contents of the file.
func load_config(config: Config) -> Error:
	assert(config is Config, "invalid argument: expected a 'Config' instance")

	_logger.info("Loading configuration from file.", {&"path": _get_filepath()})

	var err := _open_file()
	if err != OK:
		return err

	var data: Dictionary = read_var()
	assert(data is Dictionary, "invalid state: expected a dictionary value")

	config._data = read_var()

	return OK


## store_config persists the provided 'Config' instance's contents to the file.
func store_config(config: Config) -> Error:
	assert(config is Config, "invalid argument: expected a 'Config' instance")

	_logger.info("Storing configuration in file.", {&"path": _get_filepath()})

	var err := _open_file()
	if err != OK:
		return err

	store_var(config._data)

	return OK


## sync_config is a convenience method which first hydrates the provided 'Config'
## instance with the file's contents and then saves the config to disk each time a
## change is detected.
##
## NOTE: If the provided 'Config' is already being synced then nothing occurs. If a
## different 'Config' instance is being synced, that one will be unsynced first.
## Finally, synchronization will automatically be cleaned up on tree exit.
func sync_config(config: Config) -> Error:
	assert(config is Config, "invalid argument: expected a 'Config' instance")

	if config == _connected:
		return OK

	if _connected != null:
		unsync_config(_connected)

	_logger.info("Syncing configuration to file.", {&"path": _get_filepath()})

	var err := load_config(config)
	if err != OK:
		return err

	err = config.changed.connect(_on_Config_changed) as Error
	if err != OK:
		return err

	_connected = config

	return OK


## unsync_config stops syncing the specified 'Config' instance.
##
## NOTE: If the provided instance is not being synced, or no instance is currently being
## synced, nothing happens.
func unsync_config(config: Config) -> void:
	assert(config is Config, "invalid argument: expected a 'Config' instance")

	if _connected == null or config != _connected:
		return

	_logger.info("Stopping configuration sync to file.", {&"path": _get_filepath()})

	assert(
		_connected.changed.is_connected(_on_Config_changed),
		"invalid state: missing signal connection",
	)

	if _connected.changed.is_connected(_on_Config_changed):
		_connected.changed.disconnect(_on_Config_changed)

	_connected = null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	super._enter_tree()

	_logger = _logger.named(&"std/config/writer")


func _exit_tree() -> void:
	super._exit_tree()

	if _connected != null:
		unsync_config(_connected)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


# NOTE: This method must be overridden.
func _get_filepath() -> String:
	assert(false, "unimplemented")
	return ""


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _open_file() -> Error:
	if is_open():
		return OK

	return open(_get_filepath())


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Config_changed(_category: StringName, _key: StringName) -> void:
	assert(_connected is Config, "invalid state: missing signal emitter")

	store_config(_connected)
