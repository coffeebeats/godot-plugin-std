##
## std/input/glyph.gd
##
## InputGlyph is a `TextureRect` node which displays an icon corresponding to the input
## origin which is currently bound to the configured action.
##
##
## TODO: Handle fallback textures for states like unbound, unknown, and missing.
##

class_name InputGlyph
extends TextureRect

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

@export_group("Properties")

## glyph_type_override_property is a settings property which specifies an override for
## the device type when determining which glyph set to display for an origin.
@export var glyph_type_override_property: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: InputSlot = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(_slot.device_activated, _on_InputSlot_device_activated)
	(
		Signals
		. disconnect_safe(
			glyph_type_override_property.value_changed,
			_on_StdSettingsPropertyInt_value_changed,
		)
	)


func _ready() -> void:
	_slot = InputSlot.for_player(player_id)
	assert(_slot is InputSlot, "invalid state; missing input slot")

	Signals.connect_safe(_slot.device_activated, _on_InputSlot_device_activated)

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
	var data := _slot.get_action_glyph(action_set.name, action)
	if not data:
		texture = null
		return

	texture = data.texture


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_InputSlot_device_activated(_device: InputDevice) -> void:
	_update_texture()


func _on_StdSettingsPropertyInt_value_changed() -> void:
	_update_texture()
