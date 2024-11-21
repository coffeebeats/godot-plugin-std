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

# NOTE: Add a space character to disambiguate with property of same name.
@export_category("Scope ")

## scope is the settings scope to which this property will read and writes its value.
@export var scope: StdSettingsScope = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_value reads the specified property from the configured `StdSettingsScope`.
func get_value() -> Variant:
	assert(scope is StdSettingsScope, "invalid state; missing scope")
	return _get_value_from_config(scope.config)


## set_value sets the specified property on the configured `StdSettingsScope`.
func set_value(value: Variant) -> bool:
	assert(scope is StdSettingsScope, "invalid config; missing 'scope'")

	if readonly:
		push_warning("tried to write a read-only property: %s::%s" % [category, name])
		return false

	if _set_value_on_config(scope.config, value):
		value_changed.emit(value)
		return true

	return false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(_config: Config) -> Variant:
	assert(false, "unimplemented")
	return null


func _set_value_on_config(_config: Config, _value) -> bool:
	assert(false, "unimplemented")
	return false
