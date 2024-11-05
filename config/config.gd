##
## std/config/config.gd
##
## Config is a collection of categorized key-value pairs, conceptually similar to INI-
## style configuration files. This is meant as a secure replacement for 'ConfigFile'
## that doesn't load 'Variant' types from disk [1]. Although the API is simpler, it also
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


## erase clears the value associated with the `key` in `category`.
func erase(category: StringName, key: StringName) -> bool:
	return _delete_key(category, key)


## get_float retrieves the value associated with `key` in `category` if one is set and
## it's type is a 'float'. If no value is associated then 'default' is returned.
func get_float(category: StringName, key: StringName, default: float) -> float:
	var value: Variant = _get_variant(category, key)
	return value if value is float else default


## get_int retrieves the value associated with `key` in `category` if one is set and
## it's type is a 'int'. If no value is associated then 'default' is returned.
func get_int(category: StringName, key: StringName, default: int) -> int:
	var value: Variant = _get_variant(category, key)
	return value if value is int else default


## get_string retrieves the value associated with `key` in `category` if one is set and
## it's type is a `String`. If no value is associated then 'default' is returned.
func get_string(category: StringName, key: StringName, default: String) -> String:
	var value: Variant = _get_variant(category, key)
	return value if value is String else default

## get_vector2 retrieves the value associated with `key` in `category` if one is set and
## it's type is a 'vector2'. If no value is associated then 'default' is returned.
func get_vector2(category: StringName, key: StringName, default: Vector2) -> Vector2:
	var value: Variant = _get_variant(category, key)
	return value if value is Vector2 else default

## has_float returns whether there is a 'float'-typed value associated with `key` in
## `category`.
func has_float(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is float


## has_int returns whether there is a 'int'-typed value associated with `key` in
## `category`.
func has_int(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is int


## has_string returns whether there is a `String`-typed value associated with `key` in
## `category`.
func has_string(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is String

## has_vector2 returns whether there is a `Vector2`-typed value associated with `key` in
## `category`.
func has_vector2(category: StringName, key: StringName) -> bool:
	var value: Variant = _get_variant(category, key)
	return value is Vector2


## set_float updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_float(category: StringName, key: StringName, value: float) -> bool:
	return _set_variant(category, key, value)


## set_int updates the value associated with `key` in `category` and returns whether the
## value was changed.
func set_int(category: StringName, key: StringName, value: int) -> bool:
	return _set_variant(category, key, value)


## set_string updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_string(category: StringName, key: StringName, value: String) -> bool:
	return _set_variant(category, key, value)

## set_vector2 updates the value associated with `key` in `category` and returns whether
## the value was changed.
func set_vector2(category: StringName, key: StringName, value: Vector2) -> bool:
	return _set_variant(category, key, value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


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
