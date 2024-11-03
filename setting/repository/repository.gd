##
## std/setting/repository/repository.gd
##
## SettingsRepository wraps a 'Config' instance and makes it available throughout the
## scene tree to a 'SettingsController'.
##

@tool
class_name SettingsRepository
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../../config/config.gd")
const ConfigWithFileSync := preload("../../config/file.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# TODO(#44): Replace this with a custom group to utilize membership notifications.
const _GROUP_SETTINGS_REPOSITORY := &"addons/std/setting:repository"

# -- CONFIGURATION ------------------------------------------------------------------- #

## id is a globally unique identifier for the "scope" of contained settings.
@export var id: StringName = "":
	set(value):
		id = value
		update_configuration_warnings()

## writer is a node path to an optional 'ConfigWriter' used to persist the configuration
## to disk.
##
## NOTE: If present, values will first be loaded from disk. This initial hydration won't
## trigger observable change notifications unless the observer is configured to be
## called on first load.
@export_node_path var writer := NodePath()

## observers is a list of 'SettingsRepositoryObserver' resources which will be notified
## when properties matching their interest are changed.
@export var observers: Array[SettingsRepositoryObserver] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

## TODO(#42): Refactor this to use debounced writes.
## config is the 'Config' object containing the current state.
var config: Config = null

var _observers: Dictionary = {}
var _writer: ConfigWriter = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_in_tree finds a 'SettingsRepository' in the scene tree with the provided ID.
static func find_in_tree(tree: SceneTree, target: StringName) -> SettingsRepository:
	var nodes := tree.get_nodes_in_group(_GROUP_SETTINGS_REPOSITORY)
	for node in nodes:
		var repository: SettingsRepository = node
		assert(
			repository is SettingsRepository,
			"invalid state: expected repository node",
		)

		if repository.id == target:
			return repository

	return null


## add_observer registers the provided 'SettingsRepositoryObserver', causing it to be
## notified whenever one of the properties it cares about is changed.
func add_observer(observer: SettingsRepositoryObserver) -> void:
	assert(observer is SettingsRepositoryObserver, "missing argument: observer")

	for property in observer.get_settings_properties():
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
	config = Config.new()

	assert(_is_unique_repository(), "invalid state; found duplicate repository")
	add_to_group(_GROUP_SETTINGS_REPOSITORY)

	
	var err := config.changed.connect(_on_Config_changed)
	assert(err == OK, "failed to connect to signal")

	for observer in observers:
		add_observer(observer)


func _exit_tree() -> void:
	remove_from_group(_GROUP_SETTINGS_REPOSITORY)

	assert(config.changed.is_connected(_on_Config_changed), "missing connection")
	config.changed.disconnect(_on_Config_changed)

	config = null


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if id == "":
		out.append("Invalid config; missing property 'id'!")

	return out


func _ready() -> void:
	assert(id != &"", "invalid configuration; missing property: id")

	if writer:
		_writer = get_node(writer)
		assert(_writer is ConfigWriter, "invalid config: expected a config writer")

		var err := _writer.sync_config(config)
		assert(err == OK, "failed to synchronize settings repository")

	# NOTE: This must be done in '_ready' so that an attached 'ConfigWriter' has had a
	# chance to hydrate the configuration values.
	for property in _observers:
		for observer in _observers[property]:
			if not observer.should_call_on_value_loaded:
				continue

			observer.handle_value_change(
				property,
				property.get_value_from_config(config),
			)

	
# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _is_unique_repository() -> bool:
	for node in get_tree().get_nodes_in_group(_GROUP_SETTINGS_REPOSITORY):
		if node is SettingsRepository and node.id == id:
			return false

	return true


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Config_changed(category: StringName, key: StringName) -> void:
	for property in _observers:
		assert(property is SettingsProperty, "invalid type")

		if property.category != category:
			continue

		if property.name != key:
			continue

		var value: Variant = property.get_value_from_config(config)

		for observer in _observers[property]:
			assert(observer is SettingsRepositoryObserver, "invalid type")
			observer.handle_value_change(property, value)
