##
## std/setting/property/property.gd
##
## SettingsProperty is a handle that identifies a single property within a settings
## scope (i.e. repository). This is a base class which should be extended with type-
## specific logic.
##

extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../../config/config.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## category is the category within a 'Config' instance.
@export var category: StringName = ""

## name is the key within a 'Config' instance category.
@export var name: StringName = ""

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## get_value_from_config reads the specified property from a 'Config' instance.
func get_value_from_config(config: Config) -> Variant:
	return _get_value_from_config(config)

## set_value_on_config sets the specified property on a 'Config' instance.
func set_value_on_config(config: Config, value: Variant) -> bool:
	return _set_value_on_config(config, value)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _get_value_from_config(_config: Config) -> Variant:
	assert(false, "unimplemented")
	return null

func _set_value_on_config(_config: Config, _value) -> bool:
	assert(false, "unimplemented")
	return false
