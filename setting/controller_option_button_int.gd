##
## std/setting/controller_option_button_int.gd
##
## `StdSettingsControllerOptionButtonInt` is a class which drives an `OptionButton`
## node consisting of `int` items.
##

@tool
class_name StdSettingsControllerOptionButtonInt
extends StdSettingsControllerOptionButton

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a settings property defining which configuration property to update.
@export var property: StdSettingsPropertyInt = null:
	set(value):
		property = value
		update_configuration_warnings()

## `options_property` is a settings property defining the list of options to choose
## from. To customize how those options are displayed, provide a
## `StdSettingsOptionButtonFormatter`.
@export var options_property: StdSettingsPropertyIntList = null:
	set(value):
		options_property = value
		update_configuration_warnings()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_property() -> StdSettingsProperty:
	return property


func _get_options_property() -> StdSettingsProperty:
	return options_property


func _is_valid_options_property() -> bool:
	return options_property is StdSettingsPropertyIntList
