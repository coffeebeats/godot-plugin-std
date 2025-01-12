##
## std/config/item.gd
##
## StdConfigItem is a collection of key/value pairs that can be marshaled to or
## unmarshaled from a `Config` object.
##

class_name StdConfigItem
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const PROPERTY_KEY_CATEGORY := &"category"
const PROPERTY_KEY_NAME := &"name"
const PROPERTY_KEY_TYPE := &"type"
const PROPERTY_KEY_USAGE := &"usage"

# -- CONFIGURATION ------------------------------------------------------------------- #

## category is the name of the `Config` category which contains the definition for this
## item.
@export var category: StringName = &""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## marshal populates the provided `Config` instance with this config item's properties.
## Only exported script variables will be stored.
func marshal(config: Config) -> void:
	if not category:
		assert(false, "invalid config; missing category")
		return

	for property in get_property_list():
		if not (property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		if name == PROPERTY_KEY_CATEGORY:
			continue

		var type: Variant.Type = property[PROPERTY_KEY_TYPE]
		var value: Variant = get(name)

		if (
			typeof(value) != type
			or (
				value == property_get_revert(name)
				or (value == type_convert(null, type))
				# Cannot convert `null` to `String` type, so explicitly handle below.
				or (value is String and value == "")
			)
		):
			config.erase(category, name)
			continue

		match type:
			TYPE_BOOL:
				assert(value is bool, "invalid state; wrong type")
				config.set_bool(category, name, value)
			TYPE_FLOAT:
				assert(value is float, "invalid state; wrong type")
				config.set_float(category, name, value)
			TYPE_INT:
				assert(value is int, "invalid state; wrong type")
				config.set_int(category, name, value)
			TYPE_PACKED_INT64_ARRAY:
				assert(value is PackedInt64Array, "invalid state; wrong type")
				config.set_int_list(category, name, value)
			TYPE_PACKED_STRING_ARRAY:
				assert(value is PackedStringArray, "invalid state; wrong type")
				config.set_string_list(category, name, value)
			TYPE_PACKED_VECTOR2_ARRAY:
				assert(value is PackedVector2Array, "invalid state; wrong type")
				config.set_vector2_list(category, name, value)
			TYPE_STRING:
				assert(value is String, "invalid state; wrong type")
				config.set_string(category, name, value)
			TYPE_VECTOR2:
				assert(value is Vector2, "invalid state; wrong type")
				config.set_vector2(category, name, value)


## unmarshal reads configuration data from the provided `Config` instance and updates
## this config item's properties. Only exported script variables will be set.
func unmarshal(config: Config) -> void:
	if not category:
		assert(false, "invalid config; missing category")
		return

	for property in get_property_list():
		if not (property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		if name == PROPERTY_KEY_CATEGORY:
			continue

		var type: Variant.Type = property[PROPERTY_KEY_TYPE]
		var value: Variant = config.get_variant(category, name, null)

		if value == null or typeof(value) != type:
			self.set(name, type_convert(null, type) if type != TYPE_STRING else "")
			continue

		set(name, value)
