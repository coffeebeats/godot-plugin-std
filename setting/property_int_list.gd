##
## std/setting/property_int_list.gd
##
## `StdSettingsPropertyIntList` is a handle that identifies a single
## 'PackedInt64Array' property within a settings scope (i.e. repository). It can also
## be used to modify a provided `Config` instance.
##

class_name StdSettingsPropertyIntList
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: PackedInt64Array

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_int_list(category, name, default)


func _set_value_on_config(config: Config, value: PackedInt64Array) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_int_list(category, name, value)
