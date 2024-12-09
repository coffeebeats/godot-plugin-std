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
@export var action_set: InputActionSet = null

## action is the name of the input action which the glyph icon will correspond to.
@export var action := &""

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `InputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1:
	set(value):
		player_id = value

		if is_inside_tree():
			_slot = InputSlot.for_player(player_id)

@export_group("Display")

## label is a path to a `Label` node which will render glyph text, if set. A default
## `Label` will be created if this is unset.
@export_node_path var label: NodePath = "Label"

## texture_rect is a path to a `TextureRect` node which will render a glyph texture, if
## set. A default `TextureRect` will be created if this is unset.
@export_node_path var texture_rect: NodePath = "TextureRect"

@export_group("Properties")

## glyph_type_override_property is a settings property which specifies an override for
## the device type when determining which glyph set to display for an origin.
@export var glyph_type_override_property: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: InputSlot = null

@onready var _label: Label = get_node_or_null(label)
@onready var _texture_rect: TextureRect = get_node_or_null(texture_rect)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(_slot.device_activated, _on_InputSlot_device_activated)
	(
		Signals
		.disconnect_safe(
			glyph_type_override_property.value_changed,
			_on_StdSettingsPropertyInt_value_changed,
		)
	)


func _ready() -> void:
	# Create missing child nodes.
	if not _texture_rect:
		_texture_rect = _create_texture_rect()
		add_child(_texture_rect, false, INTERNAL_MODE_BACK)
		texture_rect = get_path_to(_texture_rect)
	if not _label:
		_label = _create_label()
		add_child(_label, false, INTERNAL_MODE_BACK)
		label = get_path_to(_label)

	_label.visible = false
	_texture_rect.visible = false

	# Wire up glyph data connections.
	_slot = InputSlot.for_player(player_id)
	assert(_slot is InputSlot, "invalid state; missing input slot")

	Signals.connect_safe(_slot.device_activated, _on_InputSlot_device_activated)

	assert(
		glyph_type_override_property is StdSettingsPropertyInt,
		"invalid config; missing property",
	)
	(
		Signals
		.connect_safe(
			glyph_type_override_property.value_changed,
			_on_StdSettingsPropertyInt_value_changed,
		)
	)

	# Initialize texture on first ready.
	_update_texture()


# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _create_label() -> Label:
	var node := Label.new()
	node.set_anchors_preset(LayoutPreset.PRESET_CENTER)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	return node

func _create_texture_rect() -> TextureRect:
	var node := TextureRect.new()
	node.set_anchors_preset(LayoutPreset.PRESET_CENTER)
	node.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT

	return node

func _update_texture() -> void:
	var data := _slot.get_action_glyph(action_set.name, action)
	if not data:
		_label.text = ""
		_label.visible = false
		_texture_rect.texture = null
		_texture_rect.visible = false

		return

	if data.texture:
		_texture_rect.texture = data.texture
		_texture_rect.visible = true

	if data.label:
		_label.text = data.label
		_label.visible = true

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_InputSlot_device_activated(_device: InputDevice) -> void:
	_update_texture()


func _on_StdSettingsPropertyInt_value_changed() -> void:
	_update_texture()
