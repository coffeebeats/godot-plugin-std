##
## std/setting/property_vector2_list.gd
##
## `StdSettingsPropertyVector2List` is a handle that identifies a single
## `PackedVector2Array` property within a settings scope (i.e. repository). It can also
## be used to modify a provided `Config` instance.
##

class_name StdSettingsPropertyVector2List
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: PackedVector2Array = PackedVector2Array()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_vector2_list(category, name, default)


func _set_value_on_config(config: Config, value: PackedVector2Array) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_vector2_list(category, name, value)
