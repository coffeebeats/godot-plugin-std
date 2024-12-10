##
## std/setting/property_bool_and.gd
##
## `StdSettingsPropertyBoolAnd` is a handle that identifies settings property that
## evaluates to `true` if all of the configured boolean property values are `true`.
##
## NOTE: This settings property does *not* emit `value_changed` signals when its
## dependent properties change. Instead, this setting should be manually checked as
## needed.
##

class_name StdSettingsPropertyBoolAnd
extends StdSettingsPropertyBool

# -- CONFIGURATION ------------------------------------------------------------------- #

## properties is a list of boolean settings properties which will be evaluated. If all
## are `true`, then this settings property evaluates to `true`.
@export var properties: Array[StdSettingsPropertyBool] = []

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _can_modify() -> bool:
	return false

func _get_value_from_config(_config: Config) -> Variant:
	assert(not default, "invalid config; conflicting default value")

	for property in properties:
		if not property.get_value():
			return false

	return false
