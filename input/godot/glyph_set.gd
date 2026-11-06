##
## std/input/godot/glyph_set.gd
##
## `StdInputGlyphSet` is a base class for collections of glyph icon resources for
## specific device types.
##

class_name StdInputGlyphSet
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_types is a list of input device types to which these glyph icons pertain.
@export var device_types: Array[StdInputDevice.DeviceType] = []

## unknown_glyph is the glyph returned for a bound origin no matching set has art for,
## taken from the first matching set which sets one. With it empty in every matching
## set, the provider's `unknown_glyph` is returned instead.
@export var unknown_glyph: Texture2D = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_origin_glyph returns the configured resource for the provided input event.
## `target_size` is the size the host draws the glyph at, so a set can pick or draw
## art to fit it; zero leaves the size to the set.
func get_origin_glyph(
	event: InputEvent,
	target_size: Vector2 = Vector2.ZERO,
) -> Texture2D:
	assert(device_types, "invalid config; missing device type")
	return _get_origin_glyph(event, target_size)


## matches returns whether this glyph set can be used for the specified device type.
func matches(device_type: StdInputDevice.DeviceType) -> bool:
	assert(device_types, "invalid config; missing device type")
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: unknown device type",
	)

	return device_type in device_types


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(
	_event: InputEvent,
	_target_size: Vector2,
) -> Texture2D:
	assert(false, "unimplemented")
	return null
