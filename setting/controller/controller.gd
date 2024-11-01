##
## std/setting/controller/controller.gd
##
## SettingController is a base class for a node which allows "remote" management of UI
## settings controls. Effectively, this node allows for decoupling settings state from
## the UI which modifies it.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SettingsProperty := preload("../property/property.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## repository is a reference to the settings repository which should be notified upon a
## value changing.
@export var repository: SettingsRepositoryHandle = null

## target is the path to the node which should be controlled/observed.
@export_node_path var target: NodePath = NodePath("..")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _repository: SettingsRepository = null
var _target: Node = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
    _target = get_node(target)
    assert(_target is Node, "missing target node: %s" % target)

    _repository = SettingsRepository.find_in_tree(get_tree(), repository)
    assert(_repository is SettingsRepository, "missing settings repository")
