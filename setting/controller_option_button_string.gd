##
## std/setting/controller_option_button_string.gd
##
## `StdSettingsControllerOptionButtonString` is a class which drives an `OptionButton`
## node consisting of `String` items.
##

@tool
class_name StdSettingsControllerOptionButtonString
extends StdSettingsControllerOptionButton

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_valid_property() -> bool:
	return property is StdSettingsPropertyString


func _is_valid_options_property() -> bool:
	return options_property is StdSettingsPropertyStringList
