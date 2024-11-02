##
## std/setting/controller/controller.gd
##
## SettingsController is a base class for a node which allows "remote" management of UI
## settings controls. Effectively, this node allows for decoupling settings state from
## the UI which modifies it.
##

@tool
class_name SettingsController
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## repository is a reference to the settings repository which should be notified upon a
## value changing.
@export var repository_id: StringName = "":
	set(value):
		repository_id = value
		update_configuration_warnings()

## target is the path to the node which should be controlled/observed.
@export_node_path var target: NodePath = NodePath(".."):
	set(value):
		target = value
		update_configuration_warnings()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _repository: SettingsRepository = null
var _target: Node = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_target = get_node(target)
	assert(_target is Node, "missing target node: %s" % target)

	_repository = SettingsRepository.find_in_tree(get_tree(), repository_id)
	assert(_repository is SettingsRepository, "missing settings repository")


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if repository_id == &"":
		out.append("Invalid config; missing property 'id'!")
	if target == NodePath():
		out.append("Invalid config; missing 'target'property!")

	return out
