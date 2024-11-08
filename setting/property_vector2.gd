##
## std/setting/property_vector2.gd
##
## `StdSettingsPropertyVector2` is a handle that identifies a single `Vector2` property
## within a settings scope (i.e. repository). It can also be used to modify a provided
## `Config` instance.
##

class_name StdSettingsPropertyVector2
extends StdSettingsProperty

# -- CONFIGURATION ------------------------------------------------------------------- #

## default is the value that will be returned from `Config` reads if the property
## doesn't have a value defined.
@export var default: Vector2

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_vector2(category, name, default)


func _set_value_on_config(config: Config, value: Vector2) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_vector2(category, name, value)
