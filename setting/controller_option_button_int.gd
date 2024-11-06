##
## std/setting/controller_option_button_int.gd
##
## `StdSettingsControllerOptionButtonInt` is a class which drives an `OptionButton`
## node consisting of `int` items.
##

@tool
class_name StdSettingsControllerOptionButtonInt
extends StdSettingsControllerOptionButton

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_valid_property() -> bool:
	return property is StdSettingsPropertyInt


func _is_valid_options_property() -> bool:
	return options_property is StdSettingsPropertyIntList
