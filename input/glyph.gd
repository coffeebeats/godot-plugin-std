##
## std/input/glyph.gd
##
## StdInputGlyph is a `TextureRect` node which displays an icon corresponding to the
## input origin which is currently bound to the configured action.
##
## TODO: Handle fallback textures for states like unbound, unknown, and missing.
##

class_name StdInputGlyph
extends Control

# -- DEFINITIONS --------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null

## action is the name of the input action which the glyph icon will correspond to.
@export var action := &""

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1:
	set(value):
		player_id = value

		if is_inside_tree():
			_slot = StdInputSlot.for_player(player_id)

@export_group("Display")

## show_label defines whether the bound origin's display name should be shown if one
## is defined.
@export var show_label: bool = false

## use_size_as_target controls whether this `Glyph` node's size should be used as the
## target size to pass to the device.
@export var use_size_as_target: bool = false:
	set(value):
		use_size_as_target = value

		if use_size_as_target and target_size_override != Vector2.ZERO:
			target_size_override = Vector2.ZERO

## target_size_override is a specific target size for the rendered origin glyph. This
## will be ignored if `use_size_as_target` is `true`. A zero value will not constrain
## the texture's size.
@export var target_size_override: Vector2 = Vector2.ZERO

@export_subgroup("Origin info")

## label is a path to a `Label` node which will render glyph text, if set. A default
## `Label` will be created if this is unset.
@export_node_path var label: NodePath = "Label"

## texture_rect is a path to a `TextureRect` node which will render a glyph texture, if
## set. A default `TextureRect` will be created if this is unset.
@export_node_path var texture_rect: NodePath = "TextureRect"

@export_subgroup("Containers")

## label_container is a path to a node which will be hidden upon the origin label being
## empty. By default this will be the `Label` used to display the origin label itself.
@export_node_path var label_container: NodePath = "Label"

## texture_rect_container is a path to a node which will be hidden upon the origin glyph
## texture being `null`. By default this will be the `TextureRect` used to display the
## glyph icon itself.
@export_node_path var texture_rect_container: NodePath = "TextureRect"

@export_group("Properties")

## glyph_type_override_property is a settings property which specifies an override for
## the device type when determining which glyph set to display for an origin.
@export var glyph_type_override_property: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: StdInputSlot = null

@onready var _label: Label = get_node(label)
@onready var _label_container: Control = get_node(label_container)
@onready var _texture_rect: TextureRect = get_node(texture_rect)
@onready var _texture_rect_container: Control = get_node(texture_rect_container)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(
		_slot.action_configuration_changed, _on_StdInputSlot_configuration_changed
	)
	Signals.disconnect_safe(_slot.device_activated, _on_StdInputSlot_device_activated)
	(
		Signals
		. disconnect_safe(
			glyph_type_override_property.value_changed,
			_on_StdSettingsPropertyInt_value_changed,
		)
	)


func _ready() -> void:
	assert(action_set is StdInputActionSet, "invalid config; missing action set")

	# Wire up glyph data connections.
	_slot = StdInputSlot.for_player(player_id)
	assert(_slot is StdInputSlot, "invalid state; missing input slot")

	Signals.connect_safe(
		_slot.action_configuration_changed, _on_StdInputSlot_configuration_changed
	)
	Signals.connect_safe(_slot.device_activated, _on_StdInputSlot_device_activated)

	assert(
		glyph_type_override_property is StdSettingsPropertyInt,
		"invalid config; missing property",
	)
	(
		Signals
		. connect_safe(
			glyph_type_override_property.value_changed,
			_on_StdSettingsPropertyInt_value_changed,
		)
	)

	# Initialize texture on first ready.
	_update_texture()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_texture() -> void:
	_label.text = ""
	_label_container.visible = false
	_texture_rect.texture = null
	_texture_rect_container.visible = false

	var target_size := size if use_size_as_target else target_size_override

	var data := _slot.get_action_glyph(action_set.name, action, target_size)
	if not data:
		return

	if data.texture:
		_texture_rect.texture = data.texture
		_texture_rect_container.visible = true
		custom_minimum_size = data.texture.get_size()

	if show_label:
		var origin_label := _slot.get_action_origin_label(action_set.name, action)
		if origin_label:
			_label.text = origin_label.to_upper()
			_label_container.visible = true

	update_minimum_size()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_StdInputSlot_configuration_changed() -> void:
	_update_texture()


func _on_StdInputSlot_device_activated(_device: StdInputDevice) -> void:
	_update_texture()


func _on_StdSettingsPropertyInt_value_changed() -> void:
	_update_texture()
