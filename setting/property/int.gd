##
## std/setting/property/int.gd
##
## SettingsIntProperty is a handle that identifies a single 'int' property within a
## settings scope (i.e. repository). It can also be used to modify a provided 'Config'
## instance.
##

class_name SettingsIntProperty
extends SettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from 'Config' reads if the property
## doesn't have a value defined.
@export var default: int

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_int(category, name, default)


func _set_value_on_config(config: Config, value: int) -> bool:
	return config.set_int(category, name, value)
