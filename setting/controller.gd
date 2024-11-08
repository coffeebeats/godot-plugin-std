##
## std/setting/controller.gd
##
## `StdSettingsController` is a base class for a node which allows "remote" management
## of UI settings controls. Effectively, this node allows for decoupling settings state
## from the UI which modifies it.
##

@tool
class_name StdSettingsController
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is a reference to the settings scope to which changes should be pushed. Initial
## state will also be read from the scope.
@export var scope: StdSettingsScope = null:
	set(value):
		scope = value
		update_configuration_warnings()

## target is the path to the node which should be controlled/observed.
@export_node_path var target: NodePath = NodePath(".."):
	set(value):
		target = value
		update_configuration_warnings()

# -- INITIALIZATION ------------------------------------------------------------------ #

@warning_ignore("unused_private_class_variable")
@onready var _target: Node = get_node(target)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not scope is StdSettingsScope:
		(
			warnings
			.append(
				"missing or invalid property: scope (expected a 'StdSettingsScope')",
			)
		)

	if target == NodePath():
		warnings.append("missing property: target (expected path to target UI node)")
	elif get_node(target) == null:
		warnings.append("invalid property: target node not found")
	elif not _is_valid_target():
		warnings.append("invalid property: target")

	if not _get_property() is StdSettingsProperty:
		warnings.append("invalid config: missing property")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(_is_valid_target(), "invalid type: target")
	assert(_get_property() is StdSettingsProperty, "invalid state: missing property")

	_initialize()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_property() -> StdSettingsProperty:
	assert(false, "unimplemented")
	return null


func _is_valid_target() -> bool:
	return true


func _set_initial_value(_value) -> void:
	assert(false, "unimplemented")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _initialize() -> void:
	var property := _get_property()
	assert(property is StdSettingsProperty, "invalid state: missing property")

	var value: Variant = property.get_value_from_config(scope.config)
	_set_initial_value(value)


func _set_value(value: Variant) -> void:
	var property := _get_property()
	assert(property is StdSettingsProperty, "invalid state: missing property")

	property.set_value_on_config(scope.config, value)
