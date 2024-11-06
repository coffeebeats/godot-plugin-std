##
## std/setting/controller_option_button_vector2.gd
##
## `StdSettingsControllerOptionButtonVector2` is a class which drives an `OptionButton`
## node consisting of `Vector2` items.
##

@tool
class_name StdSettingsControllerOptionButtonVector2
extends StdSettingsControllerOptionButton

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_valid_property() -> bool:
	return property is StdSettingsPropertyVector2


func _is_valid_options_property() -> bool:
	return options_property is StdSettingsPropertyVector2List
