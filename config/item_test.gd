##
## Tests pertaining to the `StdConfigItem` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("config.gd")

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


# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_item_marshal_serializes_properties_to_config_correctly():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A populated config item.
	var item := ExampleConfigItem.new()
	item.category = &"test-category"
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# When: The item is marshaled into the config object.
	item.marshal(config)

	# Then: The config contains the expected values.
	assert_eq(config.get_bool(item.category, &"test_bool", false), true)
	assert_eq(config.get_float(item.category, &"test_float", 0.0), 1.0)
	assert_eq(config.get_int(item.category, &"test_int", 0), 1)
	assert_eq(
		config.get_int_list(item.category, &"test_int_list", PackedInt64Array()),
		PackedInt64Array([1, 2, 3])
	)
	assert_eq(config.get_string(item.category, &"test_string", ""), "string")
	assert_eq(
		config.get_string_list(item.category, &"test_string_list", PackedStringArray()),
		PackedStringArray(["a", "b", "c"])
	)
	assert_eq(
		config.get_vector2(item.category, &"test_vector2", Vector2.ZERO),
		Vector2(1.0, 1.0)
	)
	assert_eq(
		config.get_vector2_list(
			item.category, &"test_vector2_list", PackedVector2Array()
		),
		PackedVector2Array([Vector2.ZERO])
	)


func test_config_item_marshal_overwrites_existing_values():
	# Given: A `Config` category name.
	var category := &"test-category"

	# Given: A 'Config' instance with starting values.
	var config := Config.new()
	config.set_bool(category, &"test_bool", false)
	config.set_float(category, &"test_float", 0.0)
	config.set_int(category, &"test_int", 0)
	config.set_int_list(category, &"test_int_list", PackedInt64Array())
	config.set_string(category, &"test_string", "")
	config.set_string_list(category, &"test_string_list", PackedStringArray())
	config.set_vector2(category, &"test_vector2", Vector2.ZERO)
	config.set_vector2_list(category, &"test_vector2_list", PackedVector2Array())

	# Given: A config item populated with non-default values.
	var item := ExampleConfigItem.new()
	item.category = category
	item.test_bool = true
	item.test_float = 1.0
	item.test_int = 1
	item.test_int_list = PackedInt64Array([1, 2, 3])
	item.test_string = "string"
	item.test_string_list = PackedStringArray(["a", "b", "c"])
	item.test_vector2 = Vector2(1.0, 1.0)
	item.test_vector2_list = PackedVector2Array([Vector2.ZERO])

	# When: The item is marshaled into the config object.
	item.marshal(config)

	# Then: The config contains the expected values.
	assert_eq(config.get_bool(item.category, &"test_bool", false), true)
	assert_eq(config.get_float(item.category, &"test_float", 0.0), 1.0)
	assert_eq(config.get_int(item.category, &"test_int", 0), 1)
	assert_eq(
		config.get_int_list(item.category, &"test_int_list", PackedInt64Array()),
		PackedInt64Array([1, 2, 3])
	)
	assert_eq(config.get_string(item.category, &"test_string", ""), "string")
	assert_eq(
		config.get_string_list(item.category, &"test_string_list", PackedStringArray()),
		PackedStringArray(["a", "b", "c"])
	)
	assert_eq(
		config.get_vector2(item.category, &"test_vector2", Vector2.ZERO),
		Vector2(1.0, 1.0)
	)
	assert_eq(
		config.get_vector2_list(
			item.category, &"test_vector2_list", PackedVector2Array()
		),
		PackedVector2Array([Vector2.ZERO])
	)


func test_config_item_deserializes_properties_from_config_correctly():
	# Given: A new, empty config item.
	var item := ExampleConfigItem.new()
	item.category = &"test-category"

	# Given: A populated 'Config' instance.
	var config := Config.new()
	config.set_bool(item.category, &"test_bool", true)
	config.set_float(item.category, &"test_float", 1.0)
	config.set_int(item.category, &"test_int", 1)
	config.set_int_list(item.category, &"test_int_list", PackedInt64Array([1, 2, 3]))
	config.set_string(item.category, &"test_string", "string")
	config.set_string_list(
		item.category, &"test_string_list", PackedStringArray(["a", "b", "c"])
	)
	config.set_vector2(item.category, &"test_vector2", Vector2(1.0, 1.0))
	config.set_vector2_list(
		item.category, &"test_vector2_list", PackedVector2Array([Vector2.ZERO])
	)

	# When: The config is unmarshaled into the config item.
	item.unmarshal(config)

	# Then: The config contains the expected values.
	assert_eq(item.test_bool, true)
	assert_eq(item.test_float, 1.0)
	assert_eq(item.test_int, 1)
	assert_eq(item.test_int_list, PackedInt64Array([1, 2, 3]))
	assert_eq(item.test_string, "string")
	assert_eq(item.test_string_list, PackedStringArray(["a", "b", "c"]))
	assert_eq(item.test_vector2, Vector2(1.0, 1.0))
	assert_eq(item.test_vector2_list, PackedVector2Array([Vector2.ZERO]))


func test_config_item_unmarshal_ignores_other_categories():
	# Given: A new, empty config item.
	var item := ExampleConfigItem.new()
	item.category = &"test-category"

	# Given: A 'Config' instance with other categories populated.
	var config := Config.new()

	for category in [item.category + "-1", item.category + "-2", item.category + "-3"]:
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

	# When: The config is unmarshaled into the config item.
	item.unmarshal(config)

	# Then: The config contains the expected values.
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
