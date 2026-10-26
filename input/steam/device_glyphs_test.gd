##
## std/input/steam/device_glyphs_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputDeviceGlyphs`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _DEVICE_GLYPHS_PATH is the glyphs script, loaded in `before_all` rather than
## preloaded, since it can't be parsed without the `Steam` singleton the GodotSteam
## extension registers and `should_skip_script` skips this script without it.
const _DEVICE_GLYPHS_PATH := "device_glyphs.gd"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _device_glyphs: Variant = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_device_glyphs_maps_device_families_to_their_steam_input_types() -> void:
	# When/Then: A device family Steam models maps to its Steam Input type.
	assert_eq(
		_device_glyphs._get_input_type(StdInputDevice.DEVICE_TYPE_PS_4),
		Steam.INPUT_TYPE_PS4_CONTROLLER,
	)
	assert_eq(
		_device_glyphs._get_input_type(StdInputDevice.DEVICE_TYPE_XBOX_ONE),
		Steam.INPUT_TYPE_XBOXONE_CONTROLLER,
	)


func test_device_glyphs_maps_a_generic_joypad_to_the_unknown_steam_input_type() -> void:
	# When/Then: A generic joypad maps to the unknown type, which keeps each origin on
	# its controller's own type rather than translating it to Xbox's.
	assert_eq(
		_device_glyphs._get_input_type(StdInputDevice.DEVICE_TYPE_GENERIC),
		Steam.INPUT_TYPE_UNKNOWN,
	)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_DEVICE_GLYPHS_PATH
	)
	_device_glyphs = load(path)


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false
