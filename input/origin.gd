##
## Origin
##
## A shared library for encoding and decoding input events, suitable for action
## bindings, within a 64-bit integer.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

const BITMASK_INDEX_TYPE := 0
const BITMASK_INDEX_KEY := BITMASK_INDEX_TYPE + 8
const BITMASK_INDEX_JOY_AXIS := BITMASK_INDEX_KEY + 24
const BITMASK_INDEX_JOY_BUTTON := BITMASK_INDEX_JOY_AXIS + 4
const BITMASK_INDEX_MOUSE_BUTTON := BITMASK_INDEX_JOY_BUTTON + 8

const BITMASK_TYPE := (1 << 8) - 1
const BITMASK_KEY := (1 << 24) - 1
const BITMASK_JOY_AXIS := (1 << 4) - 1
const BITMASK_JOY_BUTTON := (1 << 8) - 1
const BITMASK_MOUSE_BUTTON := (1 << 4) - 1

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## encode stores the provided input event type and the specified key/axis code in an
## integer.
##
## NOTE: No value information (e.g. pressed state or strength) will be retained.
static func encode(event: InputEvent) -> int:
	if event is InputEventKey:
		var type_encoded: int = (BITMASK_INDEX_KEY & BITMASK_TYPE) << BITMASK_INDEX_TYPE
		var value_encoded: int = (event.keycode & BITMASK_KEY) << BITMASK_INDEX_KEY
		return type_encoded | value_encoded

	if event is InputEventJoypadMotion:
		var type_encoded: int = (
			(BITMASK_INDEX_JOY_AXIS & BITMASK_TYPE) << BITMASK_INDEX_TYPE
		)
		var value_encoded: int = (
			(event.axis & BITMASK_JOY_AXIS) << BITMASK_INDEX_JOY_AXIS
		)
		return type_encoded | value_encoded

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
			var value_decoded: int = (
				(value & (BITMASK_KEY << BITMASK_INDEX_KEY)) >> (BITMASK_INDEX_KEY)
			)

			var event := InputEventKey.new()
			event.keycode = value_decoded as Key

			return event

		BITMASK_INDEX_JOY_AXIS:
			var value_decoded: int = (
				(value & (BITMASK_JOY_AXIS << BITMASK_INDEX_JOY_AXIS))
				>> (BITMASK_INDEX_JOY_AXIS)
			)

			var event := InputEventJoypadMotion.new()
			event.axis = value_decoded as JoyAxis

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


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
