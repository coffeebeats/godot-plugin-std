##
## Tests pertaining to the `StdConfigItem` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class ExampleConfigItem:
	extends StdConfigItem

	@export var test_bool: bool
	@export var test_float: float
	@export var test_int: int
	@export var test_int_list: PackedInt64Array
	@export var test_string: String
	@export var test_string_list: PackedStringArray
	@export var test_vector2: Vector2
	@export var test_vector2_list: PackedVector2Array

	var ignored_field: bool  # Should not be serialized/deserialized.

	func _get_category() -> StringName:
		return &"test-category"


# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_item_copy_sets_properties_correctly():
	# Given: An empty destination item.
	var dst := ExampleConfigItem.new()

	# Given: A populated source item.
	var item := ExampleConfigItem.new()
	item.ignored_field = true  # Shouldn't be serialized!
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# When: The source config item is copied to the destination item.
	dst.copy(item)

	# Then: The items contain the expected values.
	assert_eq(dst.ignored_field, false)
	assert_eq(dst.test_bool, item.test_bool)
	assert_eq(dst.test_float, item.test_float)
	assert_eq(dst.test_int, item.test_int)
	assert_eq(dst.test_int_list, item.test_int_list)
	assert_eq(dst.test_string, item.test_string)
	assert_eq(dst.test_string_list, item.test_string_list)
	assert_eq(dst.test_vector2, item.test_vector2)
	assert_eq(dst.test_vector2_list, item.test_vector2_list)


func test_config_item_store_serializes_properties_to_config_correctly():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A populated config item.
	var item := ExampleConfigItem.new()
	item.ignored_field = true  # Shouldn't be serialized!
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# When: The item is serialized into the config object.
	item.store(config)

	# Then: The config contains the expected values.
	assert_eq(config.get_bool(item.get_category(), &"ignored_field", false), false)
	assert_eq(config.get_bool(item.get_category(), &"test_bool", false), true)
	assert_eq(config.get_float(item.get_category(), &"test_float", 0.0), 1.0)
	assert_eq(config.get_int(item.get_category(), &"test_int", 0), 1)
	assert_eq(
		config.get_int_list(item.get_category(), &"test_int_list", PackedInt64Array()),
		PackedInt64Array([1, 2, 3])
	)
	assert_eq(config.get_string(item.get_category(), &"test_string", ""), "string")
	assert_eq(
		config.get_string_list(
			item.get_category(), &"test_string_list", PackedStringArray()
		),
		PackedStringArray(["a", "b", "c"])
	)
	assert_eq(
		config.get_vector2(item.get_category(), &"test_vector2", Vector2.ZERO),
		Vector2(1.0, 1.0)
	)
	assert_eq(
		config.get_vector2_list(
			item.get_category(), &"test_vector2_list", PackedVector2Array()
		),
		PackedVector2Array([Vector2.ZERO])
	)


func test_config_item_store_overwrites_existing_values():
	# Given: A config item populated with non-default values.
	var item := ExampleConfigItem.new()
	item.ignored_field = true  # Shouldn't be serialized!
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# Given: A 'Config' instance with different values.
	var config := Config.new()
	config.set_bool(item.get_category(), &"ignored_field", false)
	config.set_bool(item.get_category(), &"test_bool", false)
	config.set_float(item.get_category(), &"test_float", 0.0)
	config.set_int(item.get_category(), &"test_int", 0)
	config.set_int_list(item.get_category(), &"test_int_list", PackedInt64Array())
	config.set_string(item.get_category(), &"test_string", "")
	config.set_string_list(
		item.get_category(), &"test_string_list", PackedStringArray()
	)
	config.set_vector2(item.get_category(), &"test_vector2", Vector2.ZERO)
	config.set_vector2_list(
		item.get_category(), &"test_vector2_list", PackedVector2Array()
	)

	# When: The item is serialized into the config object.
	item.store(config)

	# Then: The config contains the expected values.
	assert_eq(config.get_bool(item.get_category(), &"ignored_field", true), false)
	assert_eq(config.get_bool(item.get_category(), &"test_bool", false), true)
	assert_eq(config.get_float(item.get_category(), &"test_float", 0.0), 1.0)
	assert_eq(config.get_int(item.get_category(), &"test_int", 0), 1)
	assert_eq(
		config.get_int_list(item.get_category(), &"test_int_list", PackedInt64Array()),
		PackedInt64Array([1, 2, 3])
	)
	assert_eq(config.get_string(item.get_category(), &"test_string", ""), "string")
	assert_eq(
		config.get_string_list(
			item.get_category(), &"test_string_list", PackedStringArray()
		),
		PackedStringArray(["a", "b", "c"])
	)
	assert_eq(
		config.get_vector2(item.get_category(), &"test_vector2", Vector2.ZERO),
		Vector2(1.0, 1.0)
	)
	assert_eq(
		config.get_vector2_list(
			item.get_category(), &"test_vector2_list", PackedVector2Array()
		),
		PackedVector2Array([Vector2.ZERO])
	)


func test_config_item_store_erases_when_serializing_default_value():
	# Given: A config item populated with default values.
	var item := ExampleConfigItem.new()
	item.ignored_field = true
	item.test_bool = false
	item.test_float = 0.0
	item.test_int = 0
	item.test_int_list = PackedInt64Array()
	item.test_string = ""
	item.test_string_list = PackedStringArray()
	item.test_vector2 = Vector2.ZERO
	item.test_vector2_list = PackedVector2Array()

	# Given: A 'Config' instance with starting values.
	var config := Config.new()
	config.set_bool(item.get_category(), &"ignored_field", false)
	config.set_bool(item.get_category(), &"test_bool", true)
	config.set_float(item.get_category(), &"test_float", 1.0)
	config.set_int(item.get_category(), &"test_int", 1)
	config.set_int_list(
		item.get_category(), &"test_int_list", PackedInt64Array([1, 2, 3])
	)
	config.set_string(item.get_category(), &"test_string", "string")
	config.set_string_list(
		item.get_category(), &"test_string_list", PackedStringArray(["a", "b", "c"])
	)
	config.set_vector2(item.get_category(), &"test_vector2", Vector2(1.0, 1.0))
	config.set_vector2_list(
		item.get_category(), &"test_vector2_list", PackedVector2Array([Vector2.ZERO])
	)

	# When: The item is serialized into the config object.
	item.store(config)

	# Then: The default values were erased from the config object.
	assert_true(config.has_bool(item.get_category(), &"ignored_field"))  # Ignored!
	assert_false(config.has_bool(item.get_category(), &"test_bool"))
	assert_false(config.has_float(item.get_category(), &"test_float"))
	assert_false(config.has_int(item.get_category(), &"test_int"))
	assert_false(config.has_int_list(item.get_category(), &"test_int_list"))
	assert_false(config.has_string(item.get_category(), &"test_string"))
	assert_false(config.has_string_list(item.get_category(), &"test_string_list"))
	assert_false(config.has_vector2(item.get_category(), &"test_vector2"))
	assert_false(config.has_vector2_list(item.get_category(), &"test_vector2_list"))


func test_config_item_deserializes_properties_from_config_correctly():
	# Given: A new, empty config item.
	var item := ExampleConfigItem.new()

	# Given: A populated 'Config' instance.
	var config := Config.new()
	config.set_bool(item.get_category(), &"ignored_field", true)  # Should ignore!
	config.set_bool(item.get_category(), &"test_bool", true)
	config.set_float(item.get_category(), &"test_float", 1.0)
	config.set_int(item.get_category(), &"test_int", 1)
	config.set_int_list(
		item.get_category(), &"test_int_list", PackedInt64Array([1, 2, 3])
	)
	config.set_string(item.get_category(), &"test_string", "string")
	config.set_string_list(
		item.get_category(), &"test_string_list", PackedStringArray(["a", "b", "c"])
	)
	config.set_vector2(item.get_category(), &"test_vector2", Vector2(1.0, 1.0))
	config.set_vector2_list(
		item.get_category(), &"test_vector2_list", PackedVector2Array([Vector2.ZERO])
	)

	# When: The config is deserialized from the config item.
	item.load(config)

	# Then: The config contains the expected values.
	assert_eq(item.ignored_field, false)
	assert_eq(item.test_bool, true)
	assert_eq(item.test_float, 1.0)
	assert_eq(item.test_int, 1)
	assert_eq(item.test_int_list, PackedInt64Array([1, 2, 3]))
	assert_eq(item.test_string, "string")
	assert_eq(item.test_string_list, PackedStringArray(["a", "b", "c"]))
	assert_eq(item.test_vector2, Vector2(1.0, 1.0))
	assert_eq(item.test_vector2_list, PackedVector2Array([Vector2.ZERO]))


func test_config_item_load_ignores_other_categories():
	# Given: A new, empty config item.
	var item := ExampleConfigItem.new()

	# Given: A 'Config' instance with other categories populated.
	var config := Config.new()

	for category in [
		item.get_category() + "-1",
		item.get_category() + "-2",
		item.get_category() + "-3"
	]:
		config.set_bool(category, &"test_bool", true)
		config.set_float(category, &"test_float", 1.0)
		config.set_int(category, &"test_int", 1)
		config.set_int_list(category, &"test_int_list", PackedInt64Array([1, 2, 3]))
		config.set_string(category, &"test_string", "string")
		config.set_string_list(
			category, &"test_string_list", PackedStringArray(["a", "b", "c"])
		)
		config.set_vector2(category, &"test_vector2", Vector2(1.0, 1.0))
		config.set_vector2_list(
			category, &"test_vector2_list", PackedVector2Array([Vector2.ZERO])
		)

	# When: The config is deserialized from the config item.
	item.load(config)

	# Then: The config contains the expected values.
	assert_eq(item.test_bool, false)
	assert_eq(item.test_float, 0.0)
	assert_eq(item.test_int, 0)
	assert_eq(item.test_int_list, PackedInt64Array())
	assert_eq(item.test_string, "")
	assert_eq(item.test_string_list, PackedStringArray())
	assert_eq(item.test_vector2, Vector2.ZERO)
	assert_eq(item.test_vector2_list, PackedVector2Array())


func test_config_item_load_erases_values_when_missing_from_config():
	# Given: A new, empty config item.
	var item := ExampleConfigItem.new()
	item.ignored_field = true
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# Given: A 'Config' instance with other categories populated.
	var config := Config.new()

	# When: The config is deserialized from the config item.
	item.load(config)

	# Then: The config contains the expected values.
	assert_eq(item.ignored_field, true)
	assert_eq(item.test_bool, false)
	assert_eq(item.test_float, 0.0)
	assert_eq(item.test_int, 0)
	assert_eq(item.test_int_list, PackedInt64Array())
	assert_eq(item.test_string, "")
	assert_eq(item.test_string_list, PackedStringArray())
	assert_eq(item.test_vector2, Vector2.ZERO)
	assert_eq(item.test_vector2_list, PackedVector2Array())


func test_config_item_reset_restores_properties():
	# Given: A populated config item.
	var item := ExampleConfigItem.new()
	item.ignored_field = true  # Shouldn't be serialized!
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# When: The item is reset.
	item.reset()

	# Then: All relevant properties are restored to their defaults.
	assert_eq(item.ignored_field, true)  # Ignored!
	assert_eq(item.test_bool, false)
	assert_eq(item.test_float, 0.0)
	assert_eq(item.test_int, 0)
	assert_eq(item.test_int_list, PackedInt64Array())
	assert_eq(item.test_string, "")
	assert_eq(item.test_string_list, PackedStringArray())
	assert_eq(item.test_vector2, Vector2.ZERO)
	assert_eq(item.test_vector2_list, PackedVector2Array())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
