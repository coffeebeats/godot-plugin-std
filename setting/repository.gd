##
## std/setting/repository.gd
##
## `StdSettingsRepository` hosts the specified `StdSettingsScope`, ensuring it stays
## referenced for the lifespan of this node. Additionally, manages syncing the
## configuration to the specified sync target and handling settings observers.
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

	if sync_target is StdSettingsSyncTarget and not Engine.is_editor_hint():
		var node := sync_target.create_sync_target_node()
		assert(node is StdConfigWriter, "invalid state: expected a config writer")

		if node is StdConfigWriter:
			add_child(node, false, INTERNAL_MODE_FRONT)

			@warning_ignore("confusable_local_declaration")
			var err := node.sync_config(scope.config)
			assert(err == OK, "failed to sync config with writer")
