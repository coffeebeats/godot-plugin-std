##
## std/logging/sink_godot.gd
##
## StdLogSinkGodot is the default log sink that routes messages through Godot's standard
## logging functions.
##

class_name StdLogSinkGodot
extends StdLogSink

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func output(
	_name: StringName,
	level: int,
	_ts: float,
	msg: String,
	formatted: String,
	_ctx: Dictionary,
	use_bbcode: bool,
) -> void:
	var push_msg := msg if use_bbcode else formatted

	match level:
		LogLevels.LEVEL_ERROR:
			push_error(push_msg)
		LogLevels.LEVEL_WARN:
			push_warning(push_msg)
		_:
			if use_bbcode:
				print_rich(formatted)
			else:
				print(formatted)
