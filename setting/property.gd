##
## std/setting/property.gd
##
## `StdSettingsProperty` is a handle that identifies a single property within a settings
## scope (i.e. repository). This is a base class which should be extended with type-
## specific logic.
##

class_name StdSettingsProperty
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## value_changed is emitted when the property value is modified.
signal value_changed(value: Variant)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## category is the category within a `Config` instance.
@export var category: StringName = ""

## name is the key within a `Config` instance category.
@export var name: StringName = ""

## readonly controls whether the property can be used to write to configuration. This
## can be used by virtual properties to ensure changes aren't saved.
@export var readonly: bool = false

@export_category("Scope")

## scope is the settings scope to which this property will read and writes its value.
@export var scope: StdSettingsScope = null

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create("std/settings/property")  # gdlint:ignore=class-definitions-order,max-line-length

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## can_modify returns whether this settings property can be modified. While this
## typically returns the `readonly` field state, it can be overridden by certain
## settings property types. As such, this method should be checked to determine whether
## a settings property is modifiable.
func can_modify() -> bool:
	return _can_modify()


## get_value reads the specified property from the configured `StdSettingsScope`.
func get_value() -> Variant:
	assert(scope is StdSettingsScope, "invalid state; missing scope")
	return _get_value_from_config(scope.config)


## set_value sets the specified property on the configured `StdSettingsScope`.
func set_value(value: Variant) -> bool:
	assert(scope is StdSettingsScope, "invalid config; missing 'scope'")

	if not can_modify():
		(
			_logger
			. warn(
				"Attempted to write to a read-only property.",
				{&"category": category, &"name": name},
			)
		)

		return false

	if _set_value_on_config(scope.config, value):
		(
			_logger
			. debug(
				"Updated property value.",
				{&"category": category, &"name": name, &"value": value},
			)
		)

		value_changed.emit(value)
		return true

	return false


## follow causes this settings property to emit `value_changed` signals whenever the
## provided other settings property does so. This is a convenience method to simplify
## wiring up dependent properties.
func follow(other: StdSettingsProperty) -> bool:
	assert(other is StdSettingsProperty, "missing argument: other")

	if not other.value_changed.is_connected(value_changed.emit):
		(
			_logger
			. debug(
				"Started following other settings property.",
				{
					&"category": category,
					&"name": name,
					&"other": "%s/%s" % [other.category, other.name],
				},
			)
		)

		other.value_changed.connect(value_changed.emit)
		return true

	return false


## unfollow removes `value_changed` signal propagation between the provided settings
## property and this one.
func unfollow(other: StdSettingsProperty) -> bool:
	assert(other is StdSettingsProperty, "missing argument: other")

	if other.value_changed.is_connected(value_changed.emit):
		(
			_logger
			. debug(
				"Stopped following other settings property.",
				{
					&"category": category,
					&"name": name,
					&"other": "%s/%s" % [other.category, other.name],
				},
			)
		)

		other.value_changed.disconnect(value_changed.emit)
		return true

	return false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _can_modify() -> bool:
	return not readonly


func _get_value_from_config(_config: Config) -> Variant:
	assert(false, "unimplemented")
	return null


func _set_value_on_config(_config: Config, _value) -> bool:
	assert(false, "unimplemented")
	return false
