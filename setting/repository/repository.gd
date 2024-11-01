##
## std/setting/repository/repository.gd
##
## SettingsRepository wraps a 'Config' instance and makes it available throughout the
## scene tree to a 'SettingsController'.
##

class_name SettingsRepository
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../../config/config.gd")
const ConfigWithFileSync := preload("../../config/file.gd")
const SettingsController := preload("../controller/controller.gd")
const SettingsProperty := preload("../property/property.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const _GROUP_SETTINGS_REPOSITORY := &"addons/std/setting:repository"

# -- CONFIGURATION ------------------------------------------------------------------- #

## handle is an identifier for the "scope" of contained settings.
@export var handle: SettingsRepositoryHandle = null

## filepath is a file to which the settings in this repository will be synced. If
## specified, settings will first be loaded from disk and the loaded values used as the
## initial configuration state.
@export_global_file("*.dat") var filepath: String = ""

# -- INITIALIZATION ------------------------------------------------------------------ #

## TODO(#42): Refactor this to use debounced writes.
## config is the 'Config' object containing the current state.
var config: Config = null

var _observers: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_in_tree finds a 'SettingsRepository' in the scene tree with the provided handle.
static func find_in_tree(
	tree: SceneTree, target: SettingsRepositoryHandle
) -> SettingsRepository:
	var nodes := tree.get_nodes_in_group(_GROUP_SETTINGS_REPOSITORY)
	for node in nodes:
		var repository: SettingsRepository = node
		assert(
			repository is SettingsRepository,
			"invalid state: expected repository node",
		)

		if repository.handle == target:
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
	if filepath != "":
		config = ConfigWithFileSync.sync_to_file(filepath)
		assert(config is Config, "failed to create config file")
	else:
		config = Config.new()

	add_to_group(_GROUP_SETTINGS_REPOSITORY)

	var err := config.changed.connect(_on_Config_changed)
	assert(err == OK, "failed to connect to signal")


func _exit_tree() -> void:
	remove_from_group(_GROUP_SETTINGS_REPOSITORY)

	assert(config.changed.is_connected(_on_Config_changed), "missing connection")
	config.changed.disconnect(_on_Config_changed)


func _ready() -> void:
	assert(
		handle is SettingsRepositoryHandle,
		"invalid configuration; missing property: handle",
	)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Config_changed(category: StringName, key: StringName) -> void:
	for property in _observers:
		assert(property is SettingsProperty, "invalid type")

		if property.category != category:
			continue

		if property.name != key:
			continue

		for observer in _observers[property]:
			assert(observer is SettingsRepositoryObserver, "invalid type")
			(
				observer
				. handle_value_change(
					property,
					property.get_value_from_config(config),
				)
			)
