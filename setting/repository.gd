##
## std/setting/repository.gd
##
## StdSettingsRepository hosts the specified `StdSettingsScope`, ensuring it stays
## referenced for the lifespan of this node. Additionally, manages syncing the
## configuration to the specified sync target.
##

@tool
class_name StdSettingsRepository
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")
const Signals := preload("../event/signal.gd")
const Debounce := preload("../timer/debounce.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope defines the configuration this repository "hosts"/manages.
@export var scope: StdSettingsScope = null:
	set(value):
		scope = value
		update_configuration_warnings()

## sync_target defines a target destination to sync configuration to. If not provided,
## configuration will not be synced.
@export var sync_target: StdSettingsSyncTarget = null:
	set(value):
		sync_target = value
		update_configuration_warnings()

# NOTE: Insert a space to avoid overwriting global 'Timer' variable.
@export_subgroup("Debounce ")

## duration sets the minimum duration (in seconds) between writes to the file.
@export var duration: float = 0.25:
	set(value):
		duration = value
		if _debounce != null:
			_debounce.duration = value
			update_configuration_warnings()

## duration_max sets the maximum delay (in seconds) before a pending write request is
## written to the file.
@export var duration_max: float = 0.75:
	set(value):
		duration_max = value
		if _debounce != null:
			_debounce.duration_max = value
			update_configuration_warnings()

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/setting/repository")  # gdlint:ignore=class-definitions-order,max-line-length

var _debounce: Debounce = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if scope is StdSettingsScope:
		var is_changed := StdGroup.with_id(scope.get_scope_id()).add_member(self)
		assert(is_changed, "invalid state: duplicate repository registered")

	Signals.connect_safe(child_exiting_tree, _on_Self_child_exiting_tree)


func _exit_tree() -> void:
	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	if scope is StdSettingsScope:
		var is_changed := StdGroup.with_id(scope.get_scope_id()).remove_member(self)
		if not is_changed:
			push_warning("invalid state: repository not registered")

	Signals.disconnect_safe(child_exiting_tree, _on_Self_child_exiting_tree)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not scope is StdSettingsScope:
		(
			warnings
			. append(
				"missing or invalid property: scope (expected a 'StdSettingsScope')",
			)
		)

	if sync_target != null and not sync_target is StdSettingsSyncTarget:
		(
			warnings
			. append(
				"invalid property: sync_target (expected a 'StdSettingsSyncTarget')",
			)
		)

	if scope is StdSettingsScope and scope.get_repository() != self:
		warnings.append("invalid state: duplicate repository for scope")

	if not _debounce:
		return warnings

	assert(_debounce is Debounce, "invalid type: expected Debounce timer")

	if _debounce.duration != duration:
		warnings.append("Invalid config; expected valid 'duration' value!")
	if _debounce.duration_max != duration_max:
		warnings.append("Invalid config; expected valid 'duration_max' value!")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(scope is StdSettingsScope, "invalid state: missing scope")
	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	if not sync_target is StdSettingsSyncTarget:
		return

	# Configure the sync target node.
	var writer := sync_target.create_sync_target_node()
	if not writer is StdConfigWriter:
		assert(false, "invalid state: expected a config writer")
		return

	add_child(writer, false, INTERNAL_MODE_FRONT)

	var err := _sync_config(writer, scope.config)
	if err != OK:
		assert(false, "failed to sync config with writer")
		(
			_logger
			. error(
				"Failed to sync config to file.",
				{&"error": err, &"path": writer.get_filepath()},
			)
		)

	# Configure the 'Debounce' timer used to rate-limit file system writes.
	_debounce = _create_debounce_timer()
	add_child(_debounce, false, INTERNAL_MODE_FRONT)
	(
		Signals
		. connect_safe(
			_debounce.timeout,
			_on_Debounce_timeout.bind(writer, scope.config),
		)
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Creates a 'Debounce' timer node configured for file system writes.
func _create_debounce_timer() -> Debounce:
	var out := Debounce.new()

	out.duration_max = duration_max
	assert(
		out.duration_max == duration_max,
		"Invalid config; expected '%f' to be '%f'!" % [out.duration_max, duration_max]
	)

	out.duration = duration
	assert(
		out.duration == duration,
		"Invalid config; expected '%f' to be '%f'!" % [out.duration, duration]
	)

	out.execution_mode = Debounce.EXECUTION_MODE_TRAILING
	out.process_callback = Timer.TIMER_PROCESS_IDLE
	out.timeout_on_tree_exit = true

	return out


## _sync_config is a convenience method which first hydrates the provided 'Config'
## instance with the file's contents and then saves the config to disk each time a
## change is detected.
##
## NOTE: If the provided 'Config' is already being synced then nothing occurs. If a
## different 'Config' instance is being synced, that one will be unsynced first.
## Finally, synchronization will automatically be cleaned up on tree exit.
func _sync_config(writer: StdConfigWriter, config: Config) -> Error:
	assert(writer is StdConfigWriter, "invalid argument; missing config writer")
	assert(writer.is_inside_tree(), "invalid state; config writer not in scene tree")
	assert(config is Config, "invalid argument: expected a 'Config' instance")

	_logger.info("Syncing configuration to file.", {&"path": writer.get_filepath()})

	var err := config.changed.connect(_on_Config_changed) as Error
	if err != OK:
		return err

	err = writer.load_config(config).wait()
	if err != OK:
		return err

	return OK


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Config_changed(_category: StringName, _key: StringName) -> void:
	_debounce.start()


func _on_Debounce_timeout(writer: StdConfigWriter, config: Config) -> void:
	var err := writer.store_config(config).wait()
	if err != OK:
		_logger.error(
			"Failed to write config to file.", {&"path": writer.get_filepath()}
		)


func _on_Self_child_exiting_tree(node: Node) -> void:
	if node != _debounce:
		return

	# The debounce timer just flushed pending contents to disk, so the reference can be
	# safely cleaned up.
	_debounce = null
