##
## Tests pertaining to the `StdConfigSchema` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class ConfigItemTest:
	extends StdConfigItem

	@export var key: int = 0

	var category: StringName = &""

	func _get_category() -> StringName:
		return category


class ConfigSchemaTest:
	extends StdConfigSchema

	@export var item: ConfigItemTest = null


# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_schema_marshal_serializes_items_to_config_correctly():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A populated config item.
	var item := ConfigItemTest.new()
	item.key = 1
	item.category = &"category"

	# Given: A new config schema with one item set.
	var schema := ConfigSchemaTest.new()
	schema.item = item

	# When: The item is marshaled into the config object.
	schema.marshal(config)

	# Then: The config contains the expected values.
	assert_eq(config.get_int(&"category", &"key", 0), 1)


func test_config_schema_unmarshal_deserializes_items_to_config_correctly():
	# Given: A populated 'Config' instance.
	var config := Config.new()
	config.set_int(&"category", &"key", 1)

	# Given: A new, empty config item.
	var item := ConfigItemTest.new()
	item.category = &"category"

	# Given: A new config schema with one item set.
	var schema := ConfigSchemaTest.new()
	schema.item = item

	# When: The item is marshaled into the config object.
	schema.unmarshal(config)

	# Then: The config item contains the expected values.
	assert_eq(item.key, 1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
