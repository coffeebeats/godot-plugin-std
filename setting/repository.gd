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

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(scope is StdSettingsScope, "invalid state: missing scope")
	var is_changed := StdGroup.with_id(scope.get_scope_id()).add_member(self)
	assert(is_changed, "invalid state: duplicate repository registered")


func _exit_tree() -> void:
	_debounce = null

	assert(scope is StdSettingsScope, "invalid state: missing scope")
	var is_changed := StdGroup.with_id(scope.get_scope_id()).remove_member(self)
	assert(is_changed, "invalid state: repository not registered")


func _ready() -> void:
	if not writer is StdConfigWriter:
		return

	# The writer's thread starts in `StdThreadWorker._ready()`; tree ordering
	# may cause its `_ready()` to fire after the repository's.
	if not writer.is_node_ready():
		await writer.ready

	if not is_inside_tree():
		return

	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	# Configure the 'Debounce' timer used to rate-limit file system writes.
	_debounce = Debounce.create(debounce_duration, debounce_duration_max, true)
	add_child(_debounce, false, INTERNAL_MODE_FRONT)
	Signals.connect_safe(_debounce.timeout, _on_debounce_timeout)

	# Sync configuration changes to the configured writer.
	var err := _sync_config()
	if err != OK:
		assert(false, "failed to sync config with writer")
		(
			_logger
			. error(
				"Failed to sync config to file.",
				{&"error": err, &"path": writer.get_filepath()},
			)
		)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _sync_config hydrates the scope's 'Config' with the writer's file contents and then
## saves the config to disk each time a change is detected.
##
## NOTE: If the 'Config' is already being synced then nothing occurs. Synchronization
## will automatically be cleaned up on tree exit.
func _sync_config() -> Error:
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

	var err := scope.config.changed.connect(_on_config_changed) as Error
	if err != OK:
		return err

	err = writer.load_config(scope.config).wait()
	if err != OK and err != ERR_FILE_NOT_FOUND:  # A missing file is okay.
		return err

	return OK


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_config_changed(_category: StringName, _key: StringName) -> void:
	_debounce.start()


func _on_debounce_timeout() -> void:
	var err := writer.store_config(scope.config).wait()
	if err != OK:
		(
			_logger
			. error(
				"Failed to write config to file.",
				{&"path": writer.get_filepath()},
			)
		)
