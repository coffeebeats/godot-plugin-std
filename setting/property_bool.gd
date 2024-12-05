##
## std/setting/property_bool.gd
##
## `StdSettingsPropertyBool` is a handle that identifies a single 'bool' property within
## a settings scope (i.e. repository). It can also be used to modify a provided `Config`
## instance.
##

class_name StdSettingsPropertyBool
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: bool = false

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_bool(category, name, default)


func _set_value_on_config(config: Config, value: bool) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_bool(category, name, value)
