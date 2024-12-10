##
## std/setting/property_bool_feature.gd
##
## `StdSettingsPropertyBoolFeature` is a handle that identifies a settings property
## which returns whether the specified feature is enabled.
##
## NOTE: This property is read-only.
##

class_name StdSettingsPropertyBoolFeature
extends StdSettingsPropertyBool

# -- CONFIGURATION ------------------------------------------------------------------- #

## feature is the name of a feature which will be checked by this settings property.
@export var feature: StringName = ""

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _can_modify() -> bool:
	return false

func _get_value_from_config(_config: Config) -> Variant:
	return OS.has_feature(feature)
