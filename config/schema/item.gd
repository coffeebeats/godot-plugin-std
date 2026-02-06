##
## std/config/item.gd
##
## StdConfigItem is a collection of key/value pairs that can be serialized to or
## deserialized from a `Config` object.
##

class_name StdConfigItem
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const PROPERTY_KEY_NAME := &"name"
const PROPERTY_KEY_TYPE := &"type"
const PROPERTY_KEY_USAGE := &"usage"

const PROPERTY_USAGE_SERDE := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE

# -- INITIALIZATION ------------------------------------------------------------------ #

var _frozen: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clone returns a new copy of this item with all serializable properties duplicated.
func clone(freeze: bool = false) -> StdConfigItem:
	var out := duplicate()
	out._frozen = freeze
	return out


## copy hydrates this config item with the data from the provided instance. All values
## will be overwritten with those sourced from the `other` object. Values not present in
## the `other` object are set to their empty values.
func copy(other: StdConfigItem) -> void:
	if _frozen:
		assert(false, "invalid state; item is frozen")
		return

	if not other is StdConfigItem:
		assert(false, "invalid argument; missing other item object")
		return

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var type: Variant.Type = property[PROPERTY_KEY_TYPE]

		var value: Variant = other.get(name)

		if value == null or typeof(value) != type:
			self.set(name, type_convert(null, type) if type != TYPE_STRING else "")
			continue

		self.set(name, value)


## frozen returns a frozen (immutable) copy of this item. Frozen items prevent all write
## operations using the `StdConfigItem` APIs (it's still possibly to modify the item).
func frozen() -> StdConfigItem:
	var out := duplicate()
	out._frozen = true
	return out


## get_category returns the name of the `Config` category which contains the definition
## for this item.
func get_category() -> StringName:
	return _get_category()


## load reads configuration data from the provided `Config` instance and updates this
## config item's properties. Only exported script variables will be set.
func load(config: Config) -> void:
	if _frozen:
		assert(false, "invalid state; item is frozen")
		return

	var category := _get_category()
	if not category:
		assert(false, "invalid config; missing category")
		return

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var type: Variant.Type = property[PROPERTY_KEY_TYPE]
		var value: Variant = config.get_variant(category, name, null)

		if value == null or typeof(value) != type:
			self.set(name, type_convert(null, type) if type != TYPE_STRING else "")
			continue

		(
			self
			. set(
				name,
				(
					value.duplicate()
					if value is Object and value.has_method(&"duplicate")
					else value
				),
			)
		)


## reset sets all serialization-enabled properties back to their default values.
func reset() -> void:
	if _frozen:
		assert(false, "invalid state; item is frozen")
		return

	var defaults := new()

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]

		self.set(name, defaults.get(name))


## store populates the provided `Config` instance with this config item's properties.
## Only exported script variables will be stored.
func store(config: Config) -> void:
	if _frozen:
		assert(false, "invalid state; item is frozen")
		return

	var category := _get_category()
	if not category:
		assert(false, "invalid config; missing category")
		return

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
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


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	assert(false, "unimplemented")
	return &""
