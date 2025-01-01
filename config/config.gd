#gdlint:ignore=max-public-methods

##
## std/config/config.gd
##
## `Config` is a collection of categorized key-value pairs, conceptually similar to INI-
## style configuration files. This is meant as a secure replacement for `ConfigFile`
## that doesn't load `Variant` types from disk [1]. Although the API is simpler, it also
## provides new functionality like signals which notify listeners on changes.
##
## [1] https://github.com/godotengine/godot/issues/80562.
##

extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## changed is emitted whenever the value associated with a `key` in a `category` is
## changed to a new value.
signal changed(category: StringName, key: StringName)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _data: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear removes all values in `category`.
func clear(category: StringName) -> bool:
	return _delete_category(category)


## erase clears the value associated with the `key` in `category`.
func erase(category: StringName, key: StringName) -> bool:
	return _delete_key(category, key)


## get_bool retrieves the value associated with `key` in `category` if one is set and
## it's type is a `bool`. If no value is associated then `default` is returned.
func get_bool(category: StringName, key: StringName, default: bool) -> bool:
	var value: Variant = _get_variant(category, key)
	return value if value is bool else default


## get_float retrieves the value associated with `key` in `category` if one is set and
## it's type is a `float`. If no value is associated then `default` is returned.
func get_float(category: StringName, key: StringName, default: float) -> float:
	var value: Variant = _get_variant(category, key)
	return value if value is float else default


## get_int retrieves the value associated with `key` in `category` if one is set and
## it's type is a 'int'. If no value is associated then `default` is returned.
func get_int(category: StringName, key: StringName, default: int) -> int:
	var value: Variant = _get_variant(category, key)
	return value if value is int else default


## get_int_list retrieves the value associated with `key` in `category` if one is set
## and it's type is a 'PackedInt64Array'. If no value is associated then `default` is
## returned.
func get_int_list(
	category: StringName, key: StringName, default: PackedInt64Array
) -> PackedInt64Array:
	var value: Variant = _get_variant(category, key)
	return value if value is PackedInt64Array else default


## get_string retrieves the value associated with `key` in `category` if one is set and
## it's type is a `String`. If no value is associated then `default` is returned.
func get_string(category: StringName, key: StringName, default: String) -> String:
	var value: Variant = _get_variant(category, key)
	return value if value is String else default


## get_string_list retrieves the value associated with `key` in `category` if one is set
## and it's type is a `PackedStringArray`. If no value is associated then `default` is
## returned.
func get_string_list(
	category: StringName, key: StringName, default: PackedStringArray
) -> PackedStringArray:
	var value: Variant = _get_variant(category, key)
	return value if value is PackedStringArray else default


## get_vector2 retrieves the value associated with `key` in `category` if one is set and
## it's type is a `Vector2`. If no value is associated then `default` is returned.
func get_vector2(category: StringName, key: StringName, default: Vector2) -> Vector2:
	var value: Variant = _get_variant(category, key)
	return value if value is Vector2 else default


## get_vector2_list retrieves the value associated with `key` in `category` if one is
## set and it's type is a 'PackedVector2Array'. If no value is associated then `default`
## is returned.
func get_vector2_list(
	category: StringName, key: StringName, default: PackedVector2Array
) -> PackedVector2Array:
	var value: Variant = _get_variant(category, key)
	return value if value is PackedVector2Array else default


## has_bool returns whether there is a `bool`-typed value associated with `key` in
## `category`.
func has_bool(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is bool


## has_category returns whether there is any value associated with any key within the
## specified category.
func has_category(category: StringName) -> bool:
	if category not in _data:
		return false

	if not _data[category]:
		return false

	return true


## has_float returns whether there is a `float`-typed value associated with `key` in
## `category`.
func has_float(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is float


## has_int returns whether there is a 'int'-typed value associated with `key` in
## `category`.
func has_int(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is int


## has_int_list returns whether there is a 'PackedInt64Array'-typed value associated
## with `key` in `category`.
func has_int_list(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is PackedInt64Array


## has_string returns whether there is a `String`-typed value associated with `key` in
## `category`.
func has_string(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is String


## has_string_list returns whether there is a `PackedStringArray`-typed value associated
## with `key` in `category`.
func has_string_list(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is PackedStringArray


## has_vector2 returns whether there is a `Vector2`-typed value associated with `key` in
## `category`.
func has_vector2(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is Vector2


## has_vector2_list returns whether there is a `PackedVector2Array`-typed value
## associated with `key` in `category`.
func has_vector2_list(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is PackedVector2Array


## set_bool updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_bool(category: StringName, key: StringName, value: bool) -> bool:
	return _set_variant(category, key, value)


## set_float updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_float(category: StringName, key: StringName, value: float) -> bool:
	return _set_variant(category, key, value)


## set_int updates the value associated with `key` in `category` and returns whether the
## value was changed.
func set_int(category: StringName, key: StringName, value: int) -> bool:
	return _set_variant(category, key, value)


## set_int_list updates the value associated with `key` in `category` and returns
## whether the value was changed.
func set_int_list(
	category: StringName, key: StringName, value: PackedInt64Array
) -> bool:
	return _set_variant(category, key, value)


## set_string updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_string(category: StringName, key: StringName, value: String) -> bool:
	return _set_variant(category, key, value)


## set_string_list updates the value associated with `key` in `category` and returns
## whether the value was changed.
func set_string_list(
	category: StringName, key: StringName, value: PackedStringArray
) -> bool:
	return _set_variant(category, key, value)


## set_vector2 updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_vector2(category: StringName, key: StringName, value: Vector2) -> bool:
	return _set_variant(category, key, value)


## set_vector2_list updates the value associated with `key` in `category` and returns
## whether the value was changed.
func set_vector2_list(
	category: StringName, key: StringName, value: PackedVector2Array
) -> bool:
	return _set_variant(category, key, value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _delete_category(
	category: StringName,
	emit: bool = true,
) -> bool:
	assert(category != "", "invalid argument: missing category")

	if category not in _data:
		return false

	var was_updated: bool = false
	for key in _data[category].keys():
		was_updated = (_delete_key(category, key, emit) or was_updated)

	# NOTE: Ignore this result because changed status is determined by keys deleted.
	_data.erase(category)

	return was_updated


func _delete_key(
	category: StringName,
	key: StringName,
	emit: bool = true,
) -> bool:
	assert(category != "", "invalid argument: missing category")
	assert(key != "", "invalid argument: missing key")

	if category not in _data:
		return false

	var was_updated: bool = _data[category].erase(key)

	if emit and was_updated:
		changed.emit(category, key)

	return was_updated


func _get_variant(category: StringName, key: StringName) -> Variant:
	assert(category != "", "invalid argument: missing category")
	assert(key != "", "invalid argument: missing key")

	if category not in _data:
		return null

	return _data[category].get(key)


func _set_variant(
	category: StringName,
	key: StringName,
	value: Variant,
	emit: bool = true,
) -> bool:
	assert(category != "", "invalid argument: missing category")
	assert(key != "", "invalid argument: missing key")

	if category not in _data:
		_data[category] = {}

	var previous: Variant = _data[category].get(key)

	_data[category][key] = value

	var was_updated: bool = value != previous
	if emit and was_updated:
		changed.emit(category, key)

	return was_updated
