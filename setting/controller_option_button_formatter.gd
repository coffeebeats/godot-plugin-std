##
## std/setting/controller_option_button_formatter.gd
##
## `StdSettingsControllerOptionButtonFormatter` is a type which describes how to format
## the options used by a `StdSettingsControllerOptionButton`.
##

class_name StdSettingsControllerOptionButtonFormatter
extends Resource

# -- PUBLIC METHODS ------------------------------------------------------------------ #

func format_option(value: Variant) -> String:
	return _format_option(value)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(_value: Variant) -> String:
	assert(false, "unimplemented")
	return ""
