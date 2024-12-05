##
## std/setting/property_float.gd
##
## `StdSettingsPropertyFloat` is a handle that identifies a single 'float' property
## within a settings scope (i.e. repository). It can also be used to modify a provided
## `Config` instance.
##

class_name StdSettingsPropertyFloat
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: float = 0.0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_float(category, name, default)


func _set_value_on_config(config: Config, value: float) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_float(category, name, value)
