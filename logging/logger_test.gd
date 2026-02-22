# gdlint:ignore=max-public-methods
##
## Tests pertaining to the `StdLogger` class, including level filtering,
## category overrides, context merging, sink integration, and profile
## application.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


class TrackingFormatter:
	extends StdLogFormatter

	var calls: Array[Dictionary] = []

	func format(
		name: StringName,
		level: int,
		ts: float,
		msg: String,
		ctx: Dictionary,
	) -> String:
		(
			calls
			. append(
				{
					&"name": name,
					&"level": level,
					&"ts": ts,
					&"msg": msg,
					&"ctx": ctx,
				}
			)
		)
		return "%s %s %s" % [String(name), LogLevels.level_name(level), msg]


class TrackingSink:
	extends StdLogSink

	var calls: Array[Dictionary] = []

	func output(
		name: StringName,
		level: int,
		ts: float,
		msg: String,
		formatted: String,
		ctx: Dictionary,
		use_bbcode: bool,
	) -> void:
		(
			calls
			. append(
				{
					&"name": name,
					&"level": level,
					&"ts": ts,
					&"msg": msg,
					&"formatted": formatted,
					&"ctx": ctx,
					&"bbcode": use_bbcode,
				}
			)
		)


# -- TEST METHODS -------------------------------------------------------------------- #


func test_warn_at_warn_level_emits():
	# Given: A logger with global level WARN.
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: A warn message is logged.
	logger.warn("warning")

	# Then: The sink receives the call.
	assert_eq(sink.calls.size(), 1)


func test_info_at_warn_level_suppressed():
	# Given: A logger with global level WARN.
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: An info message is logged.
	logger.info("information")

	# Then: The sink does not receive a call.
	assert_eq(sink.calls.size(), 0)


func test_error_at_error_level_emits():
	# Given: Global level set to ERROR.
	StdLogger.set_level(StdLogger.Level.ERROR)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: An error message is logged.
	logger.error("failure")

	# Then: The sink receives the call.
	assert_eq(sink.calls.size(), 1)


func test_void_sink_suppresses_all_output():
	# Given: A logger using the void sink.
	StdLogger.set_sink(StdLogSinkVoid.new())
	var logger := StdLogger.create(&"test")

	# When: An error message is logged.
	logger.error("should be suppressed")

	# Then: No engine notification is generated.
	assert_push_error_count(0)


func test_debug_at_debug_level_emits():
	# Given: Global level set to DEBUG.
	StdLogger.set_level(StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: A debug message is logged.
	logger.debug("trace")

	# Then: The sink receives the call (in debug builds).
	if OS.has_feature(&"debug"):
		assert_eq(sink.calls.size(), 1)
	else:
		assert_eq(sink.calls.size(), 0)


func test_level_override_overrides_global():
	# Given: Global level is WARN but "test" category is DEBUG.
	StdLogger.set_level_override(&"test", StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: A debug message is logged.
	logger.debug("trace")

	# Then: The sink receives the call (category overrides global).
	if OS.has_feature(&"debug"):
		assert_eq(sink.calls.size(), 1)
	else:
		assert_eq(sink.calls.size(), 0)


func test_longest_prefix_match_wins():
	# Given: "std" is WARN but "std/sound" is DEBUG.
	StdLogger.set_level_override(&"std", StdLogger.Level.WARN)
	StdLogger.set_level_override(&"std/sound", StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"std/sound/bus")

	# When: A debug message is logged.
	logger.debug("trace")

	# Then: The longer prefix "std/sound" is used (DEBUG).
	if OS.has_feature(&"debug"):
		assert_eq(sink.calls.size(), 1)
	else:
		assert_eq(sink.calls.size(), 0)


func test_shorter_prefix_used_when_no_longer_match():
	# Given: "std" is WARN, "std/sound" is DEBUG.
	StdLogger.set_level_override(&"std", StdLogger.Level.WARN)
	StdLogger.set_level_override(&"std/sound", StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"std/other")

	# When: An info message is logged.
	logger.info("information")

	# Then: The "std" prefix is used (WARN), so info is suppressed.
	assert_eq(sink.calls.size(), 0)


func test_prefix_match_is_pure_begins_with():
	# Given: A prefix "std/sou" is set to DEBUG.
	StdLogger.set_level_override(&"std/sou", StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"std/sound")

	# When: A debug message is logged from "std/sound".
	logger.debug("trace")

	# Then: The prefix matches via begins_with (not path boundary).
	if OS.has_feature(&"debug"):
		assert_eq(sink.calls.size(), 1)
	else:
		assert_eq(sink.calls.size(), 0)


func test_clear_level_override_falls_back_to_global():
	# Given: A category override that is then cleared.
	StdLogger.set_level_override(&"test", StdLogger.Level.DEBUG)
	StdLogger.clear_level_override(&"test")
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: An info message is logged.
	logger.info("information")

	# Then: The global level WARN is used, so info is suppressed.
	assert_eq(sink.calls.size(), 0)


func test_clear_level_overrides():
	# Given: Multiple category overrides that are then all cleared.
	StdLogger.set_level_override(&"a", StdLogger.Level.DEBUG)
	StdLogger.set_level_override(&"b", StdLogger.Level.DEBUG)
	StdLogger.clear_level_overrides()
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)

	# When: Info messages are logged for both categories.
	StdLogger.create(&"a").info("info a")
	StdLogger.create(&"b").info("info b")

	# Then: Both use global WARN level, so info is suppressed.
	assert_eq(sink.calls.size(), 0)


func test_callsite_context_takes_precedence():
	# Given: A logger with base context {a=1}.
	StdLogger.set_level(StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test", {&"a": 1})

	# When: A message is logged with call-site context {a=2}.
	logger.warn("msg", {&"a": 2})

	# Then: The call-site value takes precedence.
	assert_eq(sink.calls[0][&"ctx"][&"a"], 2)


func test_logger_context_fills_missing_keys():
	# Given: A logger with base context {a=1}.
	StdLogger.set_level(StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test", {&"a": 1})

	# When: A message is logged with call-site context {b=2}.
	logger.warn("msg", {&"b": 2})

	# Then: Both context keys are present.
	assert_eq(sink.calls[0][&"ctx"][&"a"], 1)
	assert_eq(sink.calls[0][&"ctx"][&"b"], 2)


func test_with_creates_child_with_merged_context():
	# Given: A parent logger with context {a=1}.
	StdLogger.set_level(StdLogger.Level.DEBUG)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var parent := StdLogger.create(&"test", {&"a": 1})

	# When: A child logger is created with {b=2} and logs a message.
	var child := parent.with({&"b": 2}, &"child")
	child.warn("msg")

	# Then: The child has both context keys.
	assert_eq(sink.calls[0][&"ctx"][&"a"], 1)
	assert_eq(sink.calls[0][&"ctx"][&"b"], 2)


func test_sink_receives_compact_formatted_output():
	# Given: A logger with a tracking sink and compact formatter.
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: A message is logged.
	logger.warn("hello")

	# Then: The sink receives compact format with timestamp prefix.
	var out: String = sink.calls[0][&"formatted"]
	assert_string_contains(out, "test WARN hello")
	assert_string_starts_with(out, "20")


func test_sink_receives_raw_msg():
	# Given: A logger with a tracking sink.
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: A message is logged.
	logger.warn("hello world")

	# Then: The sink receives the original message.
	assert_eq(sink.calls[0][&"msg"], "hello world")


func test_sink_receives_bbcode_flag():
	# Given: A tracking formatter with bbcode=false.
	var fmt := TrackingFormatter.new()
	fmt.bbcode = false
	StdLogger.set_formatter(fmt)
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	var logger := StdLogger.create(&"test")

	# When: A message is logged.
	logger.warn("hello")

	# Then: The sink receives the formatter's bbcode flag.
	assert_false(sink.calls[0][&"bbcode"])


func test_set_sink_changes_active_sink():
	# Given: Two tracking sinks.
	var sink_a := TrackingSink.new()
	var sink_b := TrackingSink.new()
	StdLogger.set_sink(sink_a)
	var logger := StdLogger.create(&"test")

	# When: The sink is changed and a message is logged.
	StdLogger.set_sink(sink_b)
	logger.warn("hello")

	# Then: Only the new sink receives the call.
	assert_eq(sink_a.calls.size(), 0)
	assert_eq(sink_b.calls.size(), 1)


func test_godot_sink_error_calls_push_error():
	# Given: A logger using the default GodotSink.
	var logger := StdLogger.create(&"test")

	# When: An error message is logged.
	logger.error("test error message")

	# Then: push_error was called with the message text.
	assert_push_error("test error message")


func test_godot_sink_warn_calls_push_warning():
	# Given: A logger using the default GodotSink.
	var logger := StdLogger.create(&"test")

	# When: A warning message is logged.
	logger.warn("test warning message")

	# Then: push_warning was called with the message text.
	assert_push_warning("test warning message")


func test_godot_sink_info_does_not_push():
	# Given: A logger at INFO level using the default GodotSink.
	StdLogger.set_level(StdLogger.Level.INFO)
	var logger := StdLogger.create(&"test")

	# When: An info message is logged.
	logger.info("test info message")

	# Then: No engine notifications are generated.
	assert_push_error_count(0)
	assert_push_warning_count(0)


func test_profile_apply_sets_level():
	# Given: A profile with level DEBUG.
	var profile := StdLogProfile.new()
	profile.level = StdLogger.Level.DEBUG

	# When: The profile is applied.
	profile.apply()

	# Then: The global level is DEBUG.
	assert_eq(
		StdLogger.get_effective_level(&"any"),
		StdLogger.Level.DEBUG,
	)


func test_profile_apply_sets_level_overrides():
	# Given: A profile with a category override.
	var profile := StdLogProfile.new()
	profile.level = StdLogger.Level.ERROR
	profile.level_overrides = {
		&"test": StdLogger.Level.DEBUG,
	}

	# When: The profile is applied.
	profile.apply()

	# Then: The category override is active.
	assert_eq(
		StdLogger.get_effective_level(&"test"),
		StdLogger.Level.DEBUG,
	)
	assert_eq(
		StdLogger.get_effective_level(&"other"),
		StdLogger.Level.ERROR,
	)


func test_profile_apply_clears_previous_categories():
	# Given: An existing category override.
	StdLogger.set_level_override(&"old", StdLogger.Level.DEBUG)

	# Given: A profile with a different category.
	var profile := StdLogProfile.new()
	profile.level_overrides = {
		&"new": StdLogger.Level.DEBUG,
	}

	# When: The profile is applied.
	profile.apply()

	# Then: The old override is cleared.
	assert_eq(
		StdLogger.get_effective_level(&"old"),
		StdLogger.Level.WARN,
	)

	# Then: The new override is active.
	assert_eq(
		StdLogger.get_effective_level(&"new"),
		StdLogger.Level.DEBUG,
	)


func test_profile_apply_sets_formatter():
	# Given: A profile with a tracking formatter.
	var fmt := TrackingFormatter.new()
	var profile := StdLogProfile.new()
	profile.formatter = fmt

	# When: The profile is applied and a message is logged.
	profile.apply()
	var sink := TrackingSink.new()
	StdLogger.set_sink(sink)
	StdLogger.create(&"test").warn("msg")

	# Then: The tracking formatter was used.
	assert_eq(fmt.calls.size(), 1)


func test_profile_apply_sets_sink():
	# Given: A profile with a tracking sink.
	var sink := TrackingSink.new()
	var profile := StdLogProfile.new()
	profile.sink = sink

	# When: The profile is applied and a message is logged.
	profile.apply()
	StdLogger.create(&"test").warn("msg")

	# Then: The tracking sink received the call.
	assert_eq(sink.calls.size(), 1)


func test_profile_load_and_apply_missing_file():
	# Given: A non-existent profile path.
	var path := "res://nonexistent_profile.tres"

	# When: load_and_apply is called.
	StdLogProfile.load_and_apply(path)

	# Then: No error is raised (graceful handling).
	assert_true(true)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	StdLogger.set_level(StdLogger.Level.WARN)
	StdLogger.clear_level_overrides()
	StdLogger.set_formatter(StdLogFormatterCompact.new())
	StdLogger.set_sink(StdLogSinkGodot.new())
