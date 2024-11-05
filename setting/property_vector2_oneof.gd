##
## std/setting/property_vector2_oneof.gd
##
## `StdSettingsPropertyVector2OneOf` is a handle that identifies a single `Vector2`
## property within a settings scope (i.e. repository). The value must belong to one of
## a preconfigured set of allowed values.
##

class_name StdSettingsPropertyVector2OneOf
extends StdSettingsPropertyVector2

# -- CONFIGURATION ------------------------------------------------------------------- #

## allowed_values is the preconfigured set of allowed `Vector2` values.
@export var allowed_values := PackedVector2Array():
	get():
		return _get_allowed_values()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_allowed_values is an overridable method that enables modifying the editor-set
## list of allowed values via code.
func _get_allowed_values() -> PackedVector2Array:
	return allowed_values


func _get_value_from_config(config: Config) -> Variant:
	assert(allowed_values.has(default), "invalid config; default value not allowed")

	var value: Vector2 = super._get_value_from_config(config)
	return value if allowed_values.has(value) else default


func _set_value_on_config(config: Config, value: Vector2) -> bool:
	# NOTE: Do not store the default value, as it would prevent changing the default
	# value in later game updates.
	if not allowed_values.has(value):
		return false

	return super._set_value_on_config(config, value)
