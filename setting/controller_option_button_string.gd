##
## std/setting/controller_option_button_string.gd
##
## `StdSettingsControllerOptionButtonString` is a class which drives an `OptionButton`
## node consisting of `String` items.
##

@tool
class_name StdSettingsControllerOptionButtonString
extends StdSettingsControllerOptionButton

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a settings property defining which configuration property to update.
@export var property: StdSettingsPropertyString = null:
	set(value):
		property = value
		update_configuration_warnings()

## `options_property` is a settings property defining the list of options to choose
## from. To customize how those options are displayed, provide a
## `StdSettingsOptionButtonFormatter`.
@export var options_property: StdSettingsPropertyStringList = null:
	set(value):
		options_property = value
		update_configuration_warnings()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_property() -> StdSettingsProperty:
	return property


func _get_options_property() -> StdSettingsProperty:
	return options_property


func _is_valid_options_property() -> bool:
	return options_property is StdSettingsPropertyStringList
