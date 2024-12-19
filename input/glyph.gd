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

const Signals := preload("../event/signal.gd")

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

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

## target_label is an optional node path to a `Label` element which this node will
## update with the latest bound origin label information.
@export var target_label: NodePath = ""

## target_glyph is an optional node path to a `Control` element which this node will
## update with the latest bound origin glyph.
@export var target_glyph: NodePath = ""

@export_subgroup("Node containers")

## target_label_container is a path to a node which will be hidden upon the origin label
## being empty. If this property is empty then no node will be hidden.
@export_node_path var target_label_container: NodePath = ""

## texture_rect_container is a path to a node which will be hidden upon the origin glyph
## texture being `null`. If this property is empty then no node will be hidden.
@export_node_path var target_glyph_container: NodePath = ""

@export_subgroup("Display")

## use_target_size controls whether the glyph target `Control` node's size is used as
## the requested glyph icon size.
@export var use_target_size: bool = false:
	set(value):
		use_target_size = value

		if use_target_size and target_size_override != Vector2.ZERO:
			target_size_override = Vector2.ZERO

## target_size_override is a specific target size for the rendered origin glyph. This
## will be ignored if `use_target_size` is `true`. A zero value will not constrain the
## texture's size.
@export var target_size_override: Vector2 = Vector2.ZERO

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: StdInputSlot = null

@onready var _target_glyph: Control = get_node_or_null(target_glyph)
@onready var _target_glyph_container: Control = get_node_or_null(target_glyph_container)
@onready var _target_label: Label = get_node_or_null(target_label)
@onready var _target_label_container: Control = get_node_or_null(target_label_container)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(
		_slot.action_configuration_changed, _on_configuration_changed
	)
	Signals.disconnect_safe(_slot.device_activated, _on_device_activated)

	(
		Signals
		.disconnect_safe(
			device_type_override.value_changed,
			_on_device_type_override_value_changed,
		)
	)


func _ready() -> void:
	assert(
		not target_glyph or _target_glyph is Control,
		"invalid config; missing target node"
	)
	assert(
		not target_glyph_container or _target_glyph_container is Control,
		"invalid config; missing target node"
	)
	assert(
		not target_label or _target_label is Label,
		"invalid config; missing target node"
	)
	assert(
		not target_label_container or _target_label_container is Control,
		"invalid config; missing target node"
	)

	player_id = player_id # Trigger '_slot' update.
	assert(_slot is StdInputSlot, "invalid state; missing player slot")

	Signals.connect_safe(_slot.action_configuration_changed, _on_configuration_changed)
	Signals.connect_safe(_slot.device_activated, _on_device_activated)

	assert(
		device_type_override is StdSettingsPropertyInt,
		"invalid state; missing settings property"
	)
	(
		Signals
		.connect_safe(
			device_type_override.value_changed,
			_on_device_type_override_value_changed,
		)
	)

	# Initialize targets on first ready.
	_handle_update()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _update_target_glyph(_texture: Texture2D) -> void:
	assert(false, "unimplemented")


func _update_target_label(label: String) -> void:
	_target_label.text = label.to_upper()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _handle_update() -> void:
	if _target_glyph:
		var target_size := (
			_target_glyph.size if use_target_size else target_size_override
		)
		var texture := _slot.get_action_glyph(action_set.name, action, target_size)
		_update_target_glyph(texture)

		if _target_glyph_container:
			_target_glyph_container.visible = texture != null

	if _target_label:
		var origin_label := _slot.get_action_origin_label(action_set.name, action)
		_update_target_label(origin_label)

		if _target_label_container:
			_target_label_container.visible = origin_label != ""


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_configuration_changed() -> void:
	_handle_update()


func _on_device_activated(_device: StdInputDevice) -> void:
	_handle_update()


func _on_device_type_override_value_changed() -> void:
	_handle_update()

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
