##
## std/input/steam/device_glyphs.gd
##
## StdInputSteamDeviceGlyphs is an implemention of `StdInputDeviceActions` which uses
## the Steam Input API to retrieve origin glyph icons.
##

extends StdInputDeviceGlyphs

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamDeviceActions := preload("device_actions.gd")
const SteamJoypadMonitor := preload("joypad_monitor.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## joypad_monitor is a Steam-specific joypad monitor, used to look up slot-to-device ID
## translations.
@export var joypad_monitor: StdInputSlot.JoypadMonitor = null

## device_actions is a reference to the Steam-backed `StdInputDeviceActions` component.
@export var device_actions: StdInputDeviceActions = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _glyphs is a mapping from device origin to the loaded texture resource.
static var _glyphs: Dictionary = {}  # gdlint:ignore=class-definitions-order

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(joypad_monitor is SteamJoypadMonitor, "invalid state; missing node")
	assert(device_actions is SteamDeviceActions, "invalid state; missing node")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	slot: int,
	device_type: DeviceType,
	action_set: StringName,
	action: StringName,
) -> GlyphData:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"invalid argument; unsupported device type",
	)

	if not device_actions.is_action_set_enabled(slot, action_set):
		return null

	var action_set_handle := SteamDeviceActions.get_action_set_handle(action_set)
	if not action_set_handle:
		return null

	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return null

	var origins := PackedInt64Array()

	# TODO: Find some means of specifying ahead of time which action type this is.

	# First, consider digital actions.
	var action_handle: int = SteamDeviceActions.get_digital_action_handle(action)
	for origin in Steam.getDigitalActionOrigins(
		device, action_set_handle, action_handle
	):
		var translated_origin := _translate_origin(origin, device_type)
		if translated_origin:
			origin = translated_origin

		if origin:
			origins.append(origin)

	# Next, consider analog actions.
	action_handle = SteamDeviceActions.get_analog_action_handle(action)
	for origin in Steam.getAnalogActionOrigins(
		device, action_set_handle, action_handle
	):
		var translated_origin := _translate_origin(origin, device_type)
		if translated_origin:
			origin = translated_origin

		if origin:
			origins.append(origin)

	if not origins:
		return null

	for origin in origins:
		if origin in _glyphs:
			return _glyphs[origin]

		@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
		var path := Steam.getGlyphPNGForActionOrigin(origin, 1, 0)
		if not path:
			continue

		var texture := ImageTexture.create_from_image(Image.load_from_file(path))

		var data := GlyphData.new()
		data.texture = texture

		_glyphs[origin] = data

		return data

	return null  # gdlint:ignore=max-returns


## _translate_origin maps the provided origin to the specified Steam Input device type.
## This allows overridden device types (e.g. from player settings) to work with the
## Steam Input API.
func _translate_origin(origin: int, device_type: StdInputDevice.DeviceType) -> int:
	var target: int = Steam.INPUT_TYPE_GENERIC_XINPUT

	match device_type:
		StdInputDevice.DEVICE_TYPE_PS_4:
			target = Steam.INPUT_TYPE_PS4_CONTROLLER
		StdInputDevice.DEVICE_TYPE_PS_5:
			target = Steam.INPUT_TYPE_PS5_CONTROLLER
		StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER:
			target = Steam.INPUT_TYPE_STEAM_CONTROLLER
		StdInputDevice.DEVICE_TYPE_STEAM_DECK:
			target = Steam.INPUT_TYPE_STEAM_DECK_CONTROLLER
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR:
			target = Steam.INPUT_TYPE_SWITCH_JOYCON_PAIR
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE:
			target = Steam.INPUT_TYPE_SWITCH_JOYCON_SINGLE
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO:
			target = Steam.INPUT_TYPE_SWITCH_PRO_CONTROLLER
		StdInputDevice.DEVICE_TYPE_TOUCH:
			target = Steam.INPUT_TYPE_MOBILE_TOUCH
		StdInputDevice.DEVICE_TYPE_XBOX_360:
			target = Steam.INPUT_TYPE_XBOX360_CONTROLLER
		StdInputDevice.DEVICE_TYPE_XBOX_ONE:
			target = Steam.INPUT_TYPE_XBOXONE_CONTROLLER

	return Steam.translateActionOrigin(target, origin)