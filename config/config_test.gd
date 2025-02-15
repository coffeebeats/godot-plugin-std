##
## Tests pertaining to the `Config` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("config.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_set_float_updates_value():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: A float value is set.
	config.set_float("category", "key", 1.0)

	# Then: The value is present.
	assert_true(config.has_float("category", "key"))
	assert_eq(config.get_float("category", "key", 0.0), 1.0)

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])


func test_config_set_int_updates_value():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: A int value is set.
	config.set_int("category", "key", 1)

	# Then: The value is present.
	assert_true(config.has_int("category", "key"))
	assert_eq(config.get_int("category", "key", 0), 1)

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])


func test_config_set_string_updates_value():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: A string value is set.
	config.set_string("category", "key", "value")

	# Then: The value is present.
	assert_true(config.has_string("category", "key"))
	assert_eq(config.get_string("category", "key", ""), "value")

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])


func test_config_erase_float_removes_value():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A float value is set.
	config.set_float("category", "key", 1.0)

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: The previously set value is erased.
	config.erase("category", "key")

	# Then: The value is no longer present.
	assert_false(config.has_float("category", "key"))
	assert_eq(config.get_float("category", "key", -1.0), -1.0)

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])


func test_config_erase_int_removes_value():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A int value is set.
	config.set_int("category", "key", 1)

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: The previously set value is erased.
	config.erase("category", "key")

	# Then: The value is no longer present.
	assert_false(config.has_int("category", "key"))
	assert_eq(config.get_int("category", "key", -1), -1)

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])


func test_config_erase_string_removes_value():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A string value is set.
	config.set_string("category", "key", "value")

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: The previously set value is erased.
	config.erase("category", "key")

	# Then: The value is no longer present.
	assert_false(config.has_string("category", "key"))
	assert_eq(config.get_string("category", "key", ""), "")

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])


func test_config_reset_clears_values():
	# Given: A 'Config' instance populated with multiple categories and keys.
	var config := Config.new()
	config.set_float("category1", "key1", 1.0)
	config.set_float("category1", "key2", 1.0)
	config.set_float("category2", "key1", 1.0)
	config.set_float("category2", "key2", 1.0)

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: The `Config` object is reset.
	var got := config.reset()

	# Then: The `Config` object changed.
	assert_true(got)

	# Then: The populated values were removed.
	assert_false(config.has_float("category1", "key1"))
	assert_false(config.has_float("category1", "key2"))
	assert_false(config.has_float("category2", "key1"))
	assert_false(config.has_float("category2", "key2"))

	# Then: The 'changed' signal was emitted.
	assert_signal_emit_count(config, "changed", 4)
	assert_signal_emitted_with_parameters(config, "changed", ["category1", "key1"], 0)
	assert_signal_emitted_with_parameters(config, "changed", ["category1", "key2"], 1)
	assert_signal_emitted_with_parameters(config, "changed", ["category2", "key1"], 2)
	assert_signal_emitted_with_parameters(config, "changed", ["category2", "key2"], 3)


func test_config_reset_on_empty_object_does_nothing():
	# Given: A new, empty 'Config' instances.
	var config := Config.new()

	# Given: Signal emissions are monitored.
	watch_signals(config)

	# When: The `Config` object is reset.
	var got := config.reset()

	# Then: The `Config` object did not change.
	assert_false(got)

	# Then: The 'changed' signal was emitted.
	assert_signal_not_emitted(config, "changed")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
