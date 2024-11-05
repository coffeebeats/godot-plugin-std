##
## std/setting/property_string_oneof.gd
##
## `StdSettingsPropertyStringOneOf` is a handle that identifies a single `String`
## property within a settings scope (i.e. repository). It can also be used to modify a
## provided `Config` instance.
##

class_name StdSettingsPropertyStringOneOf
extends StdSettingsPropertyString

# -- CONFIGURATION ------------------------------------------------------------------- #

## allowed_values is the preconfigured set of allowed `String` values.
@export var allowed_values := PackedStringArray():
	get():
		return _get_allowed_values()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_allowed_values is an overridable method that enables modifying the editor-set
## list of allowed values via code.
func _get_allowed_values() -> PackedStringArray:
	return allowed_values


func _get_value_from_config(config: Config) -> Variant:
	assert(allowed_values.has(default), "invalid config; default value not allowed")

	var value: String = super._get_value_from_config(config)
	return value if allowed_values.has(value) else default


func _set_value_on_config(config: Config, value: String) -> bool:
	# NOTE: Do not store the default value, as it would prevent changing the default
	# value in later game updates.
	if not allowed_values.has(value):
		return false

	return super._set_value_on_config(config, value)
