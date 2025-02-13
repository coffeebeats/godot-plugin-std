##
## std/input/glyph.gd
##
## StdInputGlyph is a base class for a node which drives the contents of another used
## to display origin information (i.e. glyph icons and labels). This node does not have
## any opinions about how to display the information, it just provides the hooks and
## configuration needed to do so.
##

@tool
class_name StdInputGlyph
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## glyph_updated is emitted when the contents of the glyph information have _possibly_
## changed (i.e. this may fire even if no change was made). Use this to react to
## contents changes to the target node.
signal glyph_updated(has_contents: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name
const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Action")

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null

## action is the name of the input action which the glyph icon will correspond to.
@export var action := &""

## binding_index is the index/rank (e.g. primary or secondary) of the action binding.
@export var binding_index: int = 0

@export_subgroup("Player")

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

@export_subgroup("Device")

## device_type_override is an optional settings property which specifies an override for
## the device type when determining which glyph set to display for an origin.
@export var device_type_override: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _keyboard_language: String = _get_keyboard_language()
var _slot: StdInputSlot = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## update forces the glyph icon to update itself; this should be called after changing
## the action configuration.
func update() -> void:
	_handle_update()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_slot = StdInputSlot.for_player(player_id)
	assert(_slot is StdInputSlot, "invalid state; missing player slot")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not action_set is StdInputActionSet:
		warnings.append("missing action set")

	elif not action:
		warnings.append("missing action")

	elif not (
		action in action_set.actions_analog_1d
		or action in action_set.actions_analog_2d
		or action in action_set.actions_digital
		or action == action_set.action_absolute_mouse
	):
		warnings.append("invalid action; not in action set")

	elif player_id < 0:
		warnings.append("invalid action; missing player")

	return warnings


func _process(_delta: float) -> void:
	var keyboard_language := _get_keyboard_language()

	if keyboard_language != _keyboard_language:
		_keyboard_language = keyboard_language
		_handle_update()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	set_process(_slot.device_type == DeviceType.KEYBOARD)

	Signals.connect_safe(_slot.action_configuration_changed, _on_actions_changed)
	Signals.connect_safe(_slot.cursor_visibility_changed, _on_cursor_visibility_changed)
	Signals.connect_safe(_slot.device_activated, _on_device_activated)

	if device_type_override is StdSettingsPropertyInt:
		(
			Signals
			. connect_safe(
				device_type_override.value_changed,
				_on_glyph_type_property_changed,
			)
		)

	# NOTE: Defer this call so notes higher up in the scene tree can set relevant
	# properties in their `_ready` callbacks.
	_handle_update.call_deferred()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _handle_update() -> void:
	assert(action, "invalid config; missing action")
	assert(action_set is StdInputActionSet, "invalid config; missing action set")

	var device_type := _get_device_type()
	var has_contents: bool = _update_glyph(device_type)

	glyph_updated.emit(has_contents)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _action_configuration_changed can be overridden by a subclass to react to changes to
## the specified player's action configuration.
##
## NOTE: This will be called *before* the glyph is updated.
func _action_configuration_changed() -> void:
	pass


## _cursor_visibility_changed can be overridden by a subclass to react to changes to the
## the specified player's cursor visibility.
##
## NOTE: This will be called *before* the glyph is updated.
func _cursor_visibility_changed(_cursor_visible: bool) -> void:
	pass


## _device_activated can be overridden by a subclass to react to changes to the
## specified player's input device.
##
## NOTE: This will be called *before* the glyph is updated.
func _device_activated(_device: StdInputDevice) -> void:
	pass


## _get_device_type can be overridden by a subclass to change how this instance
## determines which device type to request glyph information for.
func _get_device_type() -> DeviceType:
	if device_type_override is StdSettingsPropertyInt:
		var property_value: DeviceType = device_type_override.get_value()
		if property_value != DEVICE_TYPE_UNKNOWN:
			return property_value

	return _slot.device_type


## _update_glyph should be overridden by a subclass to actually enact the content
## changes required. The return value should indicate whether the contents are populated
## so that consumers can react to changes.
##
## NOTE: The `glyph_updated` signal will automatically be emitted after this method is
## called.
func _update_glyph(_device_type: DeviceType) -> bool:
	assert(false, "unimplemented")
	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_keyboard_language() -> String:
	var index := DisplayServer.keyboard_get_current_layout()
	return DisplayServer.keyboard_get_layout_language(index)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_actions_changed() -> void:
	_action_configuration_changed()
	_handle_update()


func _on_cursor_visibility_changed(cursor_visible: bool) -> void:
	_cursor_visibility_changed(cursor_visible)
	_handle_update()


func _on_device_activated(device: StdInputDevice) -> void:
	set_process(device.device_type == DeviceType.KEYBOARD)
	_device_activated(device)
	_handle_update()


func _on_glyph_type_property_changed(_device_type: Variant) -> void:
	_handle_update()
