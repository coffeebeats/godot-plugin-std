##
## std/input/origin.gd
##
## A shared library for encoding and decoding input events, suitable for action
## bindings, within a 64-bit integer.
##
## TODO: Restructure how event data is stored by encoding "type" as an enum and using
## all of the remaining bits for each type (rather than sequentially arranging chunks
## for each event type to use).
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

const BITMASK_INDEX_TYPE := 0
const BITMASK_INDEX_KEY := BITMASK_INDEX_TYPE + 8
const BITMASK_INDEX_KEY_LOCATION := BITMASK_INDEX_KEY + 24
const BITMASK_INDEX_JOY_AXIS := BITMASK_INDEX_KEY_LOCATION + 4
const BITMASK_INDEX_JOY_AXIS_DIRECTION := BITMASK_INDEX_KEY + 4
const BITMASK_INDEX_JOY_BUTTON := BITMASK_INDEX_JOY_AXIS_DIRECTION + 2
const BITMASK_INDEX_MOUSE_BUTTON := BITMASK_INDEX_JOY_BUTTON + 8

const BITMASK_TYPE := (1 << 8) - 1
const BITMASK_KEY := (1 << 24) - 1
const BITMASK_KEY_LOCATION := (1 << 4) - 1
const BITMASK_JOY_AXIS := (1 << 4) - 1
const BITMASK_JOY_AXIS_DIRECTION := (1 << 2) - 1
const BITMASK_JOY_BUTTON := (1 << 8) - 1
const BITMASK_MOUSE_BUTTON := (1 << 4) - 1

## bitmask_indices_joy defines the set of bitmask indices that match the joypad input
## paradigm.
static var bitmask_indices_joy := PackedInt64Array(
	[BITMASK_INDEX_JOY_AXIS, BITMASK_INDEX_JOY_BUTTON]
)

## bitmask_indices_kbm defines the set of bitmask indices that match the keyboard+mouse
## input paradigm.
static var bitmask_indices_kbm := PackedInt64Array(
	[BITMASK_INDEX_KEY, BITMASK_INDEX_MOUSE_BUTTON]
)

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## encode stores the provided input event type and the specified key/axis code in an
## integer.
##
## NOTE: No value information (e.g. pressed state or strength) will be retained.
static func encode(event: InputEvent) -> int:
	if event is InputEventKey:
		# Normalize the event by ensuring physical keycode is always set. This allows
		# encoding "keycode" events (e.g. from project settings), but they will always
		# be decoded as physical - matching what the user generates.
		if event.physical_keycode == KEY_NONE:
			assert(event.keycode != KEY_NONE, "invalid config; missing keycode")
			event.physical_keycode = event.keycode

		var type_encoded: int = (BITMASK_INDEX_KEY & BITMASK_TYPE) << BITMASK_INDEX_TYPE
		var location_encoded: int = (
			(event.location & BITMASK_KEY_LOCATION) << BITMASK_INDEX_KEY_LOCATION
		)

		var value_encoded: int = (
			(event.physical_keycode & BITMASK_KEY) << BITMASK_INDEX_KEY
		)

		return type_encoded | value_encoded | location_encoded

	if event is InputEventJoypadMotion:
		var type_encoded: int = (
			(BITMASK_INDEX_JOY_AXIS & BITMASK_TYPE) << BITMASK_INDEX_TYPE
		)
		var value_encoded: int = (
			(event.axis & BITMASK_JOY_AXIS) << BITMASK_INDEX_JOY_AXIS
		)

		var direction: int = 0
		match event.axis_value:
			-1.0:
				direction = 1
			1.0:
				direction = 2
		var direction_encoded: int = (
			(direction & BITMASK_JOY_AXIS_DIRECTION) << BITMASK_INDEX_JOY_AXIS_DIRECTION
		)

		return type_encoded | value_encoded | direction_encoded

	if event is InputEventJoypadButton:
		var type_encoded: int = (
			(BITMASK_INDEX_JOY_BUTTON & BITMASK_TYPE) << BITMASK_INDEX_TYPE
		)
		var value_encoded: int = (
			(event.button_index & BITMASK_JOY_BUTTON) << BITMASK_INDEX_JOY_BUTTON
		)
		return type_encoded | value_encoded

	if event is InputEventMouseButton:
		var type_encoded: int = (
			(BITMASK_INDEX_MOUSE_BUTTON & BITMASK_TYPE) << BITMASK_INDEX_TYPE
		)
		var value_encoded: int = (
			(event.button_index & BITMASK_MOUSE_BUTTON) << BITMASK_INDEX_MOUSE_BUTTON
		)
		return type_encoded | value_encoded

	assert(false, "invalid input; unsupported event type")
	return -1


## decode parses the encoded origin integer and returns an 'InputEvent'.
##
## NOTE: No value information (e.g. pressed state or strength) will be retained.
static func decode(value: int) -> InputEvent:
	assert(value >= 0, "invalid input; value out of range")

	var type_decoded: int = (
		(value & (BITMASK_TYPE << BITMASK_INDEX_TYPE)) >> BITMASK_INDEX_TYPE
	)

	match type_decoded:
		BITMASK_INDEX_KEY:
			var location_decoded: int = (
				(value & (BITMASK_KEY_LOCATION << BITMASK_INDEX_KEY_LOCATION))
				>> (BITMASK_INDEX_KEY_LOCATION)
			)

			var value_decoded: int = (
				(value & (BITMASK_KEY << BITMASK_INDEX_KEY)) >> (BITMASK_INDEX_KEY)
			)

			var event := InputEventKey.new()
			event.keycode = value_decoded as Key
			event.location = location_decoded as KeyLocation
			event.physical_keycode = value_decoded as Key

			return event

		BITMASK_INDEX_JOY_AXIS:
			var value_decoded: int = (
				(value & (BITMASK_JOY_AXIS << BITMASK_INDEX_JOY_AXIS))
				>> (BITMASK_INDEX_JOY_AXIS)
			)

			var event := InputEventJoypadMotion.new()
			event.axis = value_decoded as JoyAxis

			match (
				(
					value
					& (BITMASK_JOY_AXIS_DIRECTION << BITMASK_INDEX_JOY_AXIS_DIRECTION)
				)
				>> (BITMASK_INDEX_JOY_AXIS_DIRECTION)
			):
				1:
					event.axis_value = -1.0
				2:
					event.axis_value = 1.0

			return event

		BITMASK_INDEX_JOY_BUTTON:
			var value_decoded: int = (
				(value & (BITMASK_JOY_BUTTON << BITMASK_INDEX_JOY_BUTTON))
				>> (BITMASK_INDEX_JOY_BUTTON)
			)

			var event := InputEventJoypadButton.new()
			event.button_index = value_decoded as JoyButton

			return event

		BITMASK_INDEX_MOUSE_BUTTON:
			var value_decoded: int = (
				(value & (BITMASK_MOUSE_BUTTON << BITMASK_INDEX_MOUSE_BUTTON))
				>> (BITMASK_INDEX_MOUSE_BUTTON)
			)

			var event := InputEventMouseButton.new()
			event.button_index = value_decoded as MouseButton

			return event

	assert(false, "invalid input; unrecognized event type")
	return null


## is_encoded_value_for_device returns whether the provided `int` value is an encoded
## input event for the specified device type.
static func is_encoded_value_for_device(
	value: int,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
) -> bool:
	if device_type <= StdInputDevice.DEVICE_TYPE_UNKNOWN:
		assert(false, "invalid argument: device type")
		return false

	if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD:
		return is_encoded_value_type(value, bitmask_indices_kbm)

	return is_encoded_value_type(value, bitmask_indices_joy)


## is_encoded_value_type returns whether the provided `int` value is an encoded input
## event for the specified control input types. Note that `indices` is a list of bitmask
## index values (e.g. [BITMASK_INDEX_KEY, BITMASK_MOUSE_BUTTON] for KB+M input).
static func is_encoded_value_type(value: int, indices: PackedInt64Array) -> bool:
	if value < 0:
		return false

	var type_decoded: int = (
		(value & (BITMASK_TYPE << BITMASK_INDEX_TYPE)) >> BITMASK_INDEX_TYPE
	)

	# FIXME(https://github.com/godotengine/godot/issues/100580): Revert to `in`.
	return indices.has(type_decoded)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
