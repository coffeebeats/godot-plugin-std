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

const Config := preload("../../config/config.gd")

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

## observers is a list of `StdSettingsObserver` resources which will be notified when
## properties matching their interest are changed.
@export var observers: Array[StdSettingsObserver] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

var _observers: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## add_observer registers the provided `StdSettingsObserver`, causing it to be notified
## whenever one of the properties it cares about is changed.
func add_observer(observer: StdSettingsObserver) -> void:
	assert(observer is StdSettingsObserver, "missing argument: observer")

	var properties := observer.get_settings_properties()
	assert(len(properties) > 0, "invalid state: observer has no properties")
	assert(not properties.has(null), "invalid config: found null property")

	for property in properties:
		if not _observers.has(property):
			_observers[property] = []

		assert(not _observers[property].has(observer), "cannot add observer twice")
		_observers[property].append(observer)

	var node := observer.mount_observer_node()
	if node != null:
		assert(node is Node, "invalid type")
		add_child(node)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	var err := scope.config.changed.connect(_on_Config_changed)
	assert(err == OK, "failed to connect to signal")

	for observer in observers:
		add_observer(observer)


func _exit_tree() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing settings scope")

	var is_changed := StdGroup.with_id(scope.get_scope_id()).remove_member(self)
	assert(is_changed, "invalid state: repository not registered")


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
	assert(scope is StdSettingsScope, "invalid config; missing settings scope")

	var is_changed := StdGroup.with_id(scope.get_scope_id()).add_member(self)
	assert(is_changed, "invalid state: duplicate repository registered")

	if sync_target is StdSettingsSyncTarget and not Engine.is_editor_hint():
		var node := sync_target.create_sync_target_node()
		assert(node is StdConfigWriter, "invalid state: expected a config writer")

		if node is StdConfigWriter:
			add_child(node, false, INTERNAL_MODE_FRONT)

			@warning_ignore("confusable_local_declaration")
			var err := node.sync_config(scope.config)
			assert(err == OK, "failed to sync config with writer")

	var err := scope.config.changed.connect(_on_Config_changed)
	assert(err == OK, "failed to connect to signal")

	for observer in observers:
		add_observer(observer)

	# NOTE: This must be done in '_ready' so that an attached 'ConfigWriter' has had a
	# chance to hydrate the configuration values.
	for property in _observers:
		for observer in _observers[property]:
			if not observer.should_call_on_value_loaded:
				continue

			(
				observer
				. handle_value_change(
					property,
					property.get_value_from_config(scope.config),
				)
			)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Config_changed(category: StringName, key: StringName) -> void:
	for property in _observers:
		assert(property is StdSettingsProperty, "invalid type")

		if property.category != category:
			continue

		if property.name != key:
			continue

		var value: Variant = property.get_value_from_config(scope.config)

		for observer in _observers[property]:
			assert(observer is StdSettingsObserver, "invalid type")
			observer.handle_value_change(property, value)
