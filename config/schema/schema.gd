##
## std/config/item.gd
##
## StdConfigItem is a collection of key/value pairs that can be serialized to or
## deserialized from a `Config` object.
##

class_name StdConfigSchema
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const PROPERTY_KEY_NAME := &"name"
const PROPERTY_KEY_TYPE := &"type"
const PROPERTY_KEY_USAGE := &"usage"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## serialize_to populates the provided `Config` instance with this schema's items.
##
## NOTE: Only exported, non-null `StdConfigItem` properties will be set on the `Config`.
func serialize_to(config: Config) -> void:
	var categories := PackedStringArray()

	for property in get_property_list():
		if not (property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		if not value is StdConfigItem:
			continue

		var category := (value as StdConfigItem).get_category()
		assert(category not in categories, "invalid config; duplicate category")
		categories.append(category)

		value.serialize_to(config)


## deserialize_from populates this schema object from the provided `Config` instance.
##
## NOTE: Only exported, non-null `StdConfigItem` properties will be updated.
func deserialize_from(config: Config) -> void:
	var categories := PackedStringArray()

	for property in get_property_list():
		if not (property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		if not value is StdConfigItem:
			continue

		var category := (value as StdConfigItem).get_category()
		assert(category not in categories, "invalid config; duplicate category")
		categories.append(category)

		value.deserialize_from(config)
