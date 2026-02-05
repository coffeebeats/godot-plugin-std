##
## std/config/schema.gd
##
## StdConfigSchema is a collection of `StdConfigItem`s that can be serialized to or
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

const PROPERTY_USAGE_SERDE := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## copy sets this config schema object to be equivalent to the provided instance. All
## values will be overwritten with those sourced from the `other` object.
func copy(other: StdConfigSchema) -> void:
	if not other is StdConfigSchema:
		assert(false, "invalid argument; missing other schema object")
		return

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)
		var value_other: Variant = other.get(name)

		# TODO: Consider relaxing in the future, but for now require all properties to
		# be non-null config items.
		if not value is StdConfigItem or not value_other is StdConfigItem:
			assert(false, "invalid config; exported schema item cannot be null")
			continue

		value.copy(value_other)


## load populates this schema object from the provided `Config` instance.
##
## NOTE: Only exported, non-null `StdConfigItem` properties will be updated.
func load(config: Config) -> void:
	var categories := PackedStringArray()

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		# TODO: Consider relaxing in the future, but for now require all properties to
		# be non-null config items.
		if not value is StdConfigItem:
			assert(false, "invalid config; exported schema item cannot be null")
			continue

		var category := (value as StdConfigItem).get_category()
		assert(category not in categories, "invalid config; duplicate category")
		categories.append(category)

		value.load(config)


## reset sets all serialization-enabled properties back to their default values.
func reset() -> void:
	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		# TODO: Consider relaxing in the future, but for now require all properties to
		# be non-null config items.
		if not value is StdConfigItem:
			assert(false, "invalid config; exported schema item cannot be null")
			continue

		value.reset()


## store populates the provided `Config` instance with this schema's items.
##
## NOTE: Only exported, non-null `StdConfigItem` properties will be set on the `Config`.
func store(config: Config) -> void:
	var categories := PackedStringArray()

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		# TODO: Consider relaxing in the future, but for now require all properties to
		# be non-null config items.
		if not value is StdConfigItem:
			assert(false, "invalid config; exported schema item cannot be null")
			continue

		var category := (value as StdConfigItem).get_category()
		assert(category not in categories, "invalid config; duplicate category")
		categories.append(category)

		value.store(config)
