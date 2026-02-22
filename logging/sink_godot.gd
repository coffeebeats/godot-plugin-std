##
## std/logging/sink_godot.gd
##
## StdLogSinkGodot is the default log sink. It routes formatted log output to Godot's
## console via `print()`/`print_rich()` and emits engine notifications via
## `push_error()`/`push_warning()` for error and warning levels.
##

class_name StdLogSinkGodot
extends StdLogSink

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func output(
	_name: StringName,
	level: int,
	msg: String,
	formatted: String,
	_ctx: Dictionary,
	use_bbcode: bool,
) -> void:
	# Console output.
	if use_bbcode:
		print_rich(formatted)
	else:
		print(formatted)

	# Engine notifications for warn/error.
	match level:
		LogLevels.LEVEL_ERROR:
			push_error(msg)
		LogLevels.LEVEL_WARN:
			push_warning(msg)
