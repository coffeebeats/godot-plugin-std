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

## target is the path to the node which should be controlled/observed.
@export_node_path var target: NodePath = NodePath(".."):
	set(value):
		target = value
		update_configuration_warnings()

@export_group("Modifiers ")
@export_subgroup("Disable input")

## disabled is a settings property defining whether to enable or disable the input.
@export var disabled: StdSettingsPropertyBool = null:
	set(value):
		disabled = value
		update_configuration_warnings()

## invert_disabled_property defines whether the value from `disabled` should be inverted
# when interpreting the "disabled" input state.
@export var invert_disabled_property: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

@warning_ignore("unused_private_class_variable")
@onready var _target: Node = get_node(target)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if target == NodePath():
		warnings.append("missing property: target (expected path to target UI node)")
	elif get_node(target) == null:
		warnings.append("invalid property: target node not found")
	elif not _is_valid_target():
		warnings.append("invalid property: target")

	if not _get_property() is StdSettingsProperty:
		warnings.append("invalid config: missing property")
	elif not _get_property().scope is StdSettingsScope:
		warnings.append("invalid config: missing 'scope' for property")
	elif disabled and not disabled.scope is StdSettingsScope:
		warnings.append("invalid config: missing 'scope' for property")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(_is_valid_target(), "invalid type: target")
	assert(_get_property() is StdSettingsProperty, "invalid state: missing property")

	assert(
		not disabled or disabled is StdSettingsPropertyBool,
		"invalid config; wrong property type",
	)
	if disabled is StdSettingsPropertyBool:
		var err := disabled.value_changed.connect(_on_disabled_value_changed)
		assert(err == OK, "failed to connect to signal")

	_initialize()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_property() -> StdSettingsProperty:
	assert(false, "unimplemented")
	return null


func _is_valid_target() -> bool:
	return true


func _set_enabled(_value: bool) -> void:
	pass


func _set_initial_value(_value) -> void:
	assert(false, "unimplemented")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _initialize() -> void:
	var property := _get_property()
	assert(property is StdSettingsProperty, "invalid state: missing property")

	var value: Variant = property.get_value()
	_set_initial_value(value)


func _set_value(value: Variant) -> void:
	var property := _get_property()
	assert(property is StdSettingsProperty, "invalid state: missing property")

	property.set_value(value)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_disabled_value_changed(value: bool) -> void:
	_set_enabled(value if invert_disabled_property else not value)
