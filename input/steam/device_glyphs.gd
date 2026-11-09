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

# -- DEFINITIONS --------------------------------------------------------------------- #

## GlyphStyle is the look of the glyph art Steam draws for an origin.
enum GlyphStyle {  # gdlint:ignore=class-definitions-order
	KNOCKOUT,  ## Coloured face buttons and white detail on a transparent background.
	LIGHT,  ## Black detail on a white background.
	DARK,  ## White detail on a black background.
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## glyph_style is the look of the glyph art fetched from Steam, so a game's pad glyphs
## can match the background they sit on.
@export var glyph_style: GlyphStyle = GlyphStyle.KNOCKOUT

## joypad_monitor is a Steam-specific joypad monitor, used to look up slot-to-device ID
## translations.
@export var joypad_monitor: StdInputSlot.JoypadMonitor = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _glyphs maps each origin, glyph size and style flags, as a `Vector3i`, to the
## texture loaded for it.
static var _glyphs: Dictionary = {}  # gdlint:ignore=class-definitions-order

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(joypad_monitor is SteamJoypadMonitor, "invalid state; missing node")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	slot: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
	target_size: Vector2,
) -> Texture2D:
	for origin in _list_action_origins(
		slot,
		device_type,
		action_set,
		action,
		index,
	):
		var glyph_size := _map_target_size_to_glyph_size(target_size)
		var flags := _get_glyph_flags(glyph_style)

		var key := Vector3i(origin, glyph_size, flags)
		if key in _glyphs:
			return _glyphs[key]

		@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
		var path := Steam.getGlyphPNGForActionOrigin(origin, glyph_size, flags)
		if not path:
			continue

		var texture := ImageTexture.create_from_image(Image.load_from_file(path))
		_glyphs[key] = texture

		return texture

	return null


func _get_action_origin_count(
	slot: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
) -> int:
	return _list_all_action_origins(slot, device_type, action_set, action).size()


func _get_action_origin_label(
	slot: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> String:
	for origin in _list_action_origins(
		slot,
		device_type,
		action_set,
		action,
		index,
	):
		var label := Steam.getStringForActionOrigin(origin)
		if label:
			return label

	return ""


func _has_action_origin(
	slot: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> bool:
	return not (
		_list_action_origins(slot, device_type, action_set, action, index).is_empty()
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_glyph_flags returns the Steam glyph style flags which draw `style`.
static func _get_glyph_flags(style: GlyphStyle) -> int:
	match style:
		GlyphStyle.LIGHT:
			return Steam.INPUT_GLYPH_STYLE_LIGHT
		GlyphStyle.DARK:
			return Steam.INPUT_GLYPH_STYLE_DARK

	return Steam.INPUT_GLYPH_STYLE_KNOCKOUT


## _get_input_type returns the Steam Input type whose origins draw the glyphs of
## `device_type`. A device type with no Steam counterpart, such as a generic joypad,
## maps to `INPUT_TYPE_UNKNOWN`, for which Steam keeps each origin on its controller's
## own type, or the closest one GodotSteam's Steamworks SDK knows.
static func _get_input_type(device_type: StdInputDevice.DeviceType) -> int:
	match device_type:
		StdInputDevice.DEVICE_TYPE_PS_4:
			return Steam.INPUT_TYPE_PS4_CONTROLLER
		StdInputDevice.DEVICE_TYPE_PS_5:
			return Steam.INPUT_TYPE_PS5_CONTROLLER
		StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER:
			return Steam.INPUT_TYPE_STEAM_CONTROLLER
		StdInputDevice.DEVICE_TYPE_STEAM_DECK:
			return Steam.INPUT_TYPE_STEAM_DECK_CONTROLLER
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR:
			return Steam.INPUT_TYPE_SWITCH_JOYCON_PAIR
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE:
			return Steam.INPUT_TYPE_SWITCH_JOYCON_SINGLE
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_LEFT:
			return Steam.INPUT_TYPE_SWITCH_JOYCON_SINGLE
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_RIGHT:
			return Steam.INPUT_TYPE_SWITCH_JOYCON_SINGLE
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO:
			return Steam.INPUT_TYPE_SWITCH_PRO_CONTROLLER
		StdInputDevice.DEVICE_TYPE_TOUCH:
			return Steam.INPUT_TYPE_MOBILE_TOUCH
		StdInputDevice.DEVICE_TYPE_XBOX_360:
			return Steam.INPUT_TYPE_XBOX360_CONTROLLER
		StdInputDevice.DEVICE_TYPE_XBOX_ONE:
			return Steam.INPUT_TYPE_XBOXONE_CONTROLLER

	return Steam.INPUT_TYPE_UNKNOWN


## _list_action_origins returns the origin bound to the action at binding `index`, as a
## list which is empty when nothing is bound there.
func _list_action_origins(
	slot: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> PackedInt64Array:
	var origins := _list_all_action_origins(slot, device_type, action_set, action)
	if index < 0 or index >= origins.size():
		return PackedInt64Array()

	return PackedInt64Array([origins[index]])


## _list_all_action_origins returns every origin bound to the action, in binding order
## and translated to the device type's glyphs.
func _list_all_action_origins(
	slot: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
) -> PackedInt64Array:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"invalid argument; unsupported device type",
	)

	var origins := PackedInt64Array()

	# NOTE: A glyph can ask about a slot no joypad occupies, such as a controller glyph
	# while none is connected, which has no origins.
	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		return origins

	# NOTE: A stick's directional actions have no Steam action of their own, so each
	# shows the stick which drives it.
	var stick := action_set.get_analog_2d_action(action)
	if stick:
		action = stick

	var action_set_handle := SteamDeviceActions.get_action_set_handle(action_set.name)
	if not action_set_handle:
		return origins

	# NOTE: Steam numbers digital and analog action handles separately, so the action's
	# kind picks both the handle and the origins queried for it.
	var raw_origins: Array = []
	if action in action_set.actions_digital:
		raw_origins = (
			Steam
			. getDigitalActionOrigins(
				device,
				action_set_handle,
				SteamDeviceActions.get_digital_action_handle(action),
			)
		)
	else:
		raw_origins = (
			Steam
			. getAnalogActionOrigins(
				device,
				action_set_handle,
				SteamDeviceActions.get_analog_action_handle(action),
			)
		)

	# NOTE: Two bindings can translate to one origin on the target device type, which
	# is listed once so a cycling glyph doesn't show it twice.
	for origin in raw_origins:
		var translated_origin := _translate_origin(origin, device_type)
		if translated_origin:
			origin = translated_origin

		if origin and origin not in origins:
			origins.append(origin)

	return origins


## _map_target_size_to_glyph_size returns the smallest Steam glyph size which covers
## `target_size`. A zero axis sets no limit, as in `custom_minimum_size`, and a zero
## size takes the medium art.
static func _map_target_size_to_glyph_size(target_size: Vector2) -> int:
	if target_size.x <= 0 and target_size.y <= 0:
		return Steam.INPUT_GLYPH_SIZE_MEDIUM

	var limit := minf(
		target_size.x if target_size.x > 0 else INF,
		target_size.y if target_size.y > 0 else INF,
	)

	if limit <= 32:
		return Steam.INPUT_GLYPH_SIZE_SMALL  # 32 x 32 px

	if limit <= 128:
		return Steam.INPUT_GLYPH_SIZE_MEDIUM  # 128 x 128 px

	return Steam.INPUT_GLYPH_SIZE_LARGE  # 256 x 256 px


## _translate_origin maps the provided origin to the specified device type's glyphs.
## This allows overridden device types (e.g. from player settings) to work with the
## Steam Input API.
func _translate_origin(origin: int, device_type: StdInputDevice.DeviceType) -> int:
	return Steam.translateActionOrigin(_get_input_type(device_type), origin)
