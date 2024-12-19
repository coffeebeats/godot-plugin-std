##
## std/input/glyph.gd
##
## StdInputGlyph is a base class for a node which drives the contents of a
## `Control` node used to display origin information (i.e. glyph icons and labels).
##
## TODO: Handle fallback textures for states like unbound, unknown, and missing.
##

@tool
class_name StdInputGlyph
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## glyph_updated is emitted when the contents of the glyph information have _possibly_
## changed (i.e. this may fire even if no change was made). Use this to react to
## contents changes to the target node.
signal glyph_updated(has_contents: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Binding")

@export_subgroup("Action")

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null

## action is the name of the input action which the glyph icon will correspond to.
@export var action := &""

@export_subgroup("Player")

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1:
	set(value):
		player_id = value

		if is_inside_tree():
			_slot = StdInputSlot.for_player(player_id)

@export_subgroup("Device")

## device_type_override is a settings property which specifies an override for the
## device type when determining which glyph set to display for an origin.
@export var device_type_override: StdSettingsPropertyInt = null

@export_group("Targets")

@export_subgroup("Origin data")

## target is a node path to a `Control` element which this node will update with the
## latest bound origin label information.
@export var target: NodePath = ".."

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: StdInputSlot = null

@onready var _target: Control = get_node_or_null(target)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(
		_slot.action_configuration_changed, _on_configuration_changed
	)
	Signals.disconnect_safe(_slot.device_activated, _on_device_activated)

	(
		Signals
		. disconnect_safe(
			device_type_override.value_changed,
			_on_device_type_override_value_changed,
		)
	)


func _ready() -> void:
	assert(action, "invalid config; missing action")
	assert(action_set is StdInputActionSet, "invalid config; missing action set")
	assert(_target is Control, "invalid config; missing target node")

	player_id = player_id  # Trigger '_slot' update.
	assert(_slot is StdInputSlot, "invalid state; missing player slot")

	Signals.connect_safe(_slot.action_configuration_changed, _on_configuration_changed)
	Signals.connect_safe(_slot.device_activated, _on_device_activated)

	assert(
		device_type_override is StdSettingsPropertyInt,
		"invalid state; missing settings property"
	)
	(
		Signals
		. connect_safe(
			device_type_override.value_changed,
			_on_device_type_override_value_changed,
		)
	)

	# Initialize targets on first ready.
	_update_target()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _update_target() -> bool:
	assert(false, "unimplemented")
	return false


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_configuration_changed() -> void:
	var has_contents: bool = _update_target()
	glyph_updated.emit(has_contents)


func _on_device_activated(_device: StdInputDevice) -> void:
	var has_contents: bool = _update_target()
	glyph_updated.emit(has_contents)


func _on_device_type_override_value_changed() -> void:
	var has_contents: bool = _update_target()
	glyph_updated.emit(has_contents)
