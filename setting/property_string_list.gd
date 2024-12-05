##
## std/setting/property_string_list.gd
##
## `StdSettingsPropertyStringList` is a handle that identifies a single
## 'PackedStringArray' property within a settings scope (i.e. repository). It can also
## be used to modify a provided `Config` instance.
##

class_name StdSettingsPropertyStringList
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: PackedStringArray = PackedStringArray()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_string_list(category, name, default)


func _set_value_on_config(config: Config, value: PackedStringArray) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_string_list(category, name, value)
