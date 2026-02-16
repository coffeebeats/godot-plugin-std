##
## std/setting/repository.gd
##
## StdSettingsRepository hosts the specified `StdSettingsScope`, ensuring it stays
## referenced for the lifespan of this node. Additionally, manages syncing the
## configuration to the specified writer node.
##

class_name StdSettingsRepository
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")
const Signals := preload("../event/signal.gd")
const Debounce := preload("../timer/debounce.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope defines the configuration this repository "hosts"/manages.
@export var scope: StdSettingsScope = null

## writer is a config writer node placed in the scene tree. If not provided,
## configuration will not be synced.
@export var writer: StdConfigWriter = null

@export_subgroup("Debounce")

## duration sets the minimum duration (in seconds) between operations.
@export var debounce_duration: float = 0.25

## debounce_duration_max sets the maximum delay (in seconds) before a pending
## operation is run.
@export var debounce_duration_max: float = 0.75

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/setting/repository")  # gdlint:ignore=class-definitions-order,max-line-length

var _debounce: Debounce = null
var _store_pending: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(scope is StdSettingsScope, "invalid state: missing scope")
	var is_changed := StdGroup.with_id(scope.get_scope_id()).add_member(self)
	assert(is_changed, "invalid state: duplicate repository registered")


func _exit_tree() -> void:
	if scope and scope.config:
		Signals.disconnect_safe(scope.config.changed, _on_config_changed)

	_debounce = null

	assert(scope is StdSettingsScope, "invalid state: missing scope")
	var is_changed := StdGroup.with_id(scope.get_scope_id()).remove_member(self)
	assert(is_changed, "invalid state: repository not registered")


func _ready() -> void:
	if not writer is StdConfigWriter:
		scope.is_loaded = true
		scope.loaded.emit.call_deferred()  # Defer so observers connect first.
		return

	_setup_sync.call_deferred()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _setup_sync configures the debounce timer and initiates an asynchronous config load.
## This is called via `call_deferred` to ensure the writer's thread has started.
func _setup_sync() -> void:
	if not is_inside_tree():
		return

	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	# Configure the 'Debounce' timer used to rate-limit file system writes.
	_debounce = Debounce.create(debounce_duration, debounce_duration_max, true)
	add_child(_debounce, false, INTERNAL_MODE_FRONT)
	Signals.connect_safe(_debounce.timeout, _on_debounce_timeout)

	_sync_config()


## _sync_config initiates an asynchronous load of the scope's configuration from the
## writer's backing store.
func _sync_config() -> void:
	assert(writer is StdConfigWriter, "invalid state; missing config writer")
	assert(
		writer.is_inside_tree(),
		"invalid state; config writer not in scene tree",
	)
	assert(
		scope.config is Config,
		"invalid argument: expected a 'Config' instance",
	)

	(
		_logger
		. info(
			"Syncing configuration to file.",
			{&"path": writer.get_filepath()},
		)
	)

	var result := writer.load_config(scope.config)
	Signals.connect_safe(result.done, _on_load_completed, CONNECT_ONE_SHOT)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_load_completed(err: Error) -> void:
	if not is_inside_tree():
		return

	if err != OK and err != ERR_FILE_NOT_FOUND:
		assert(false, "failed to sync config with writer")
		(
			_logger
			. error(
				"Failed to load config from file.",
				{&"error": err, &"path": writer.get_filepath()},
			)
		)
		return

	Signals.connect_safe(scope.config.changed, _on_config_changed)

	scope.is_loaded = true
	scope.loaded.emit()


func _on_config_changed(_category: StringName, _key: StringName) -> void:
	_debounce.start()


func _on_debounce_timeout() -> void:
	var result := writer.store_config(scope.config)
	Signals.connect_safe(result.done, _on_store_completed, CONNECT_ONE_SHOT)


func _on_store_completed(err: Error) -> void:
	if err == ERR_BUSY:
		_store_pending = true
		return

	if _store_pending:
		_store_pending = false
		_debounce.start()

	if err != OK:
		(
			_logger
			. error(
				"Failed to write config to file.",
				{&"path": writer.get_filepath()},
			)
		)
