##
## Tests pertaining to the `StdInputActionHold` class.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_mode_inherit_is_what_an_unset_settings_property_reads() -> void:
	# Given: A settings property with no default and nothing stored.
	var property := StdSettingsPropertyInt.new()
	property.category = &"test"
	property.name = &"mode"
	property.scope = StdSettingsScope.new()

	# When: Its value is read.
	var got: int = property.get_value()

	# Then: It makes no choice, so the hold's next source of a mode decides.
	assert_eq(got, StdInputActionHold.MODE_INHERIT)
