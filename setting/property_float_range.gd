##
## std/setting/property_float_range.gd
##
## `StdSettingsPropertyFloatRange` is a handle that identifies a single `float` property
## within a settings scope. Values will be restricted to the configured range.
##

class_name StdSettingsPropertyFloatRange
extends StdSettingsPropertyFloat

# -- CONFIGURATION ------------------------------------------------------------------- #

## minimum is the smallest value allowed in the range. Values lower than this will be
## raised to this value when reading and writing.
@export var minimum: float

## maximum is the largest value allowed in the range. Values higher than this will be
## lowered to this value when reading and writing.
@export var maximum: float

## step is a step size within the range to which values will be rounded. This value will
## be ignored if less than or equal to `0`.
@export var step: float = -1

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	assert(default >= minimum, "invalid config; default must be >= minimum")
	assert(default <= maximum, "invalid config; default must be <= maximum")
	assert(minimum < maximum, "invalid config: minimum must be smaller than maximum")
	assert(step <= (maximum - minimum), "invalid config; step size too large")

	var value: float = super._get_value_from_config(config)
	var value_snapped := snappedf(value, step) if step > 0.0 else value

	return clampf(value_snapped, minimum, maximum)


func _set_value_on_config(config: Config, value: float) -> bool:
	assert(default >= minimum, "invalid config; default must be >= minimum")
	assert(default <= maximum, "invalid config; default must be <= maximum")
	assert(minimum < maximum, "invalid config: minimum must be smaller than maximum")
	assert(step <= (maximum - minimum), "invalid config; step size too large")

	var value_snapped := snappedf(value, step) if step > 0.0 else value
	var value_clamped := clampf(value_snapped, minimum, maximum)

	return super._set_value_on_config(config, value_clamped)
