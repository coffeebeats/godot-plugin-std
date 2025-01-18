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

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/setting/repository")  # gdlint:ignore=class-definitions-order,max-line-length

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if scope is StdSettingsScope:
		var is_changed := StdGroup.with_id(scope.get_scope_id()).add_member(self)
		assert(is_changed, "invalid state: duplicate repository registered")


func _exit_tree() -> void:
	if scope is StdSettingsScope:
		var is_changed := StdGroup.with_id(scope.get_scope_id()).remove_member(self)
		if not is_changed:
			push_warning("invalid state: repository not registered")


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

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(scope is StdSettingsScope, "invalid state: missing scope")

	if not sync_target is StdSettingsSyncTarget:
		return

	var node := sync_target.create_sync_target_node()
	if not node is StdConfigWriter:
		assert(false, "invalid state: expected a config writer")
		return

	add_child(node, false, INTERNAL_MODE_FRONT)

	var err := _sync_config(node, scope.config)
	if err != OK:
		assert(false, "failed to sync config with writer")
		(
			_logger
			. error(
				"Failed to sync config to file.",
				{&"error": err, &"path": node.get_filepath()},
			)
		)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


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

	# TODO(https://github.com/godotengine/godot-proposals/issues/4920): Replace this
	# with a "left" `bind` call.
	var callback := func(c, k): _on_Config_changed(writer, config, c, k)
	var err := config.changed.connect(callback) as Error
	if err != OK:
		return err

	err = writer.load_config(config).wait()
	if err != OK:
		return err

	return OK


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Config_changed(
	writer: StdConfigWriter,
	config: Config,
	_category: StringName,
	_key: StringName,
) -> void:
	var err := writer.store_config(config).wait()
	if err != OK:
		_logger.error(
			"Failed to write config to file.", {&"path": writer.get_filepath()}
		)
