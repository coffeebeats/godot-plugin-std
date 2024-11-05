##
## std/setting/property_string.gd
##
## `StdSettingsPropertyString` is a handle that identifies a single 'String' property
## within a settings scope (i.e. repository). It can also be used to modify a provided
## `Config` instance.
##

class_name StdSettingsPropertyString
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: String

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_string(category, name, default)


func _set_value_on_config(config: Config, value: String) -> bool:
	return config.set_string(category, name, value)
