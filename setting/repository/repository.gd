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

# -- INITIALIZATION ------------------------------------------------------------------ #

## TODO(#42): Refactor this to use debounced writes.
## config is the 'Config' object containing the current state.
var config: Config = ConfigWithFileSync.new()

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## find_in_tree finds a 'SettingsRepository' in the scene tree with the provided handle.
static func find_in_tree(tree: SceneTree, target: SettingsRepositoryHandle) -> SettingsRepository:
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

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
    add_to_group(_GROUP_SETTINGS_REPOSITORY)

func _exit_tree() -> void:
    remove_from_group(_GROUP_SETTINGS_REPOSITORY)

func _ready() -> void:
    assert(
        handle is SettingsRepositoryHandle,
        "invalid configuration; missing property: handle",
    )
