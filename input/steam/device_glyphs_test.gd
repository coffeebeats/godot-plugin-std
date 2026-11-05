##
## std/input/steam/device_glyphs_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputDeviceGlyphs`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _DEVICE_GLYPHS_PATH is the glyphs script, loaded in `before_all`.
const _DEVICE_GLYPHS_PATH := "device_glyphs.gd"

## _STEAM_ERROR is the condition GodotSteam reports when it rejects a call because
## Steam Input isn't running, as under test.
const _STEAM_ERROR := "SteamAPI_SteamInput() == nullptr"

## _TEST_ORIGIN is the Steam origin the test action is bound to.
const _TEST_ORIGIN := Steam.INPUT_ACTION_ORIGIN_XBOXONE_A

# -- INITIALIZATION ------------------------------------------------------------------ #

var _device_glyphs: Variant = null
var _glyphs: StdInputDeviceGlyphs = null

## _seeded holds each glyph cache key a test loaded art under, erased after the test.
var _seeded: Array[Vector3i] = []

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
	# When/Then: A generic joypad maps to the unknown type.
	#
	# NOTE: Steam keeps each origin on its controller's own type for it, rather than
	# translating it to Xbox's.
	assert_eq(
		_device_glyphs._get_input_type(StdInputDevice.DEVICE_TYPE_GENERIC),
		Steam.INPUT_TYPE_UNKNOWN,
	)


func test_device_glyphs_maps_each_glyph_style_to_its_steam_flag() -> void:
	# Given: The provider's glyph styles.
	var styles: Dictionary = _device_glyphs.GlyphStyle

	# When/Then: Each style maps to the Steam flag which draws it.
	assert_eq(
		_device_glyphs._get_glyph_flags(styles.KNOCKOUT),
		Steam.INPUT_GLYPH_STYLE_KNOCKOUT,
	)
	assert_eq(
		_device_glyphs._get_glyph_flags(styles.LIGHT), Steam.INPUT_GLYPH_STYLE_LIGHT
	)
	assert_eq(
		_device_glyphs._get_glyph_flags(styles.DARK), Steam.INPUT_GLYPH_STYLE_DARK
	)


func test_device_glyphs_sizes_art_by_the_height_alone_when_width_is_zero() -> void:
	# When: The art size is picked for a host 48px tall with no width.
	var got: int = _device_glyphs._map_target_size_to_glyph_size(Vector2(0, 48))

	# Then: The medium art, which covers 48px, is picked.
	assert_eq(got, Steam.INPUT_GLYPH_SIZE_MEDIUM)


func test_device_glyphs_glyph_returns_the_origins_art() -> void:
	# Given: The test action bound to an origin.
	stub(_glyphs, "_list_all_action_origins").to_return(
		PackedInt64Array([_TEST_ORIGIN])
	)

	# Given: Art loaded for the origin.
	var texture := _seed(
		Steam.INPUT_GLYPH_SIZE_MEDIUM, Steam.INPUT_GLYPH_STYLE_KNOCKOUT
	)

	# When: The glyph is fetched.
	var got := _glyph()

	# Then: The origin's art is returned.
	assert_eq(got, texture)


func test_device_glyphs_glyph_skips_art_loaded_in_another_style() -> void:
	# Given: The test action bound to an origin.
	stub(_glyphs, "_list_all_action_origins").to_return(
		PackedInt64Array([_TEST_ORIGIN])
	)

	# Given: Art loaded for the origin in the knockout style.
	var texture := _seed(
		Steam.INPUT_GLYPH_SIZE_MEDIUM, Steam.INPUT_GLYPH_STYLE_KNOCKOUT
	)

	# Given: The provider set to the light style.
	_glyphs.glyph_style = _device_glyphs.GlyphStyle.LIGHT

	# When: The glyph is fetched, which Steam has no light image for.
	var got := _glyph()

	# Then: Steam is asked for the light image.
	assert_engine_error(_STEAM_ERROR)

	# Then: The knockout art isn't returned.
	assert_ne(got, texture)


func test_device_glyphs_glyph_skips_art_loaded_at_another_size() -> void:
	# Given: The test action bound to an origin.
	stub(_glyphs, "_list_all_action_origins").to_return(
		PackedInt64Array([_TEST_ORIGIN])
	)

	# Given: Art loaded for the origin at the medium size.
	var texture := _seed(
		Steam.INPUT_GLYPH_SIZE_MEDIUM, Steam.INPUT_GLYPH_STYLE_KNOCKOUT
	)

	# When: The glyph is fetched for a small host, which Steam has no image for.
	var got := _glyph(Vector2(24, 24))

	# Then: Steam is asked for the small image.
	assert_engine_error(_STEAM_ERROR)

	# Then: The medium art isn't returned.
	assert_ne(got, texture)


func test_device_glyphs_glyph_returns_the_unknown_glyph_without_art() -> void:
	# Given: The test action bound to an origin.
	stub(_glyphs, "_list_all_action_origins").to_return(
		PackedInt64Array([_TEST_ORIGIN])
	)

	# When: The glyph is fetched, which Steam has no image for.
	var got := _glyph()

	# Then: Steam rejects the image lookup.
	assert_engine_error(_STEAM_ERROR)

	# Then: The unknown glyph is returned.
	assert_eq(got, _glyphs.unknown_glyph)


func test_device_glyphs_glyph_returns_null_for_an_unbound_action() -> void:
	# Given: The test action bound to no origin.
	stub(_glyphs, "_list_all_action_origins").to_return(PackedInt64Array())

	# When: The glyph is fetched.
	var got := _glyph()

	# Then: No glyph is returned.
	assert_null(got)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	for key in _seeded:
		_device_glyphs._glyphs.erase(key)

	_seeded.clear()


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_DEVICE_GLYPHS_PATH
	)
	_device_glyphs = load(path)


func before_each() -> void:
	# NOTE: The component isn't added to the scene, since its `_ready` needs a Steam
	# joypad monitor; the origins it would read from Steam are stubbed.
	_glyphs = autofree(partial_double(_device_glyphs).new())
	_glyphs.unknown_glyph = PlaceholderTexture2D.new()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _glyph returns the primary Xbox glyph of the test action on slot 0, for a host
## drawing it at `target_size`.
func _glyph(target_size: Vector2 = Vector2.ZERO) -> Texture2D:
	return (
		_glyphs
		. get_action_glyph(
			0,
			StdInputDevice.DEVICE_TYPE_XBOX_ONE,
			StdInputActionSet.new(),
			&"jump",
			StdInputDeviceActions.BINDING_INDEX_PRIMARY,
			target_size,
		)
	)


## _seed loads a texture into the glyph cache for the test origin at `glyph_size` and
## style `flags`, and returns it.
func _seed(glyph_size: int, flags: int) -> Texture2D:
	var key := Vector3i(_TEST_ORIGIN, glyph_size, flags)
	var texture := PlaceholderTexture2D.new()
	_device_glyphs._glyphs[key] = texture
	_seeded.append(key)
	return texture
