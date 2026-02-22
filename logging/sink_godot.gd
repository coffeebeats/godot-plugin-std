##
## std/logging/sink_godot.gd
##
## StdLogSinkGodot is the default log sink. In the editor, error and warning messages
## are routed through `push_error()`/`push_warning()`; all other output uses print
## methods. Outside of the editor, all messages use print methods with the formatted
## string.
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
	var is_editor := Engine.is_editor_hint()

	if is_editor and level == LogLevels.LEVEL_ERROR:
		push_error(msg)
	elif is_editor and level == LogLevels.LEVEL_WARN:
		push_warning(msg)
	elif use_bbcode:
		print_rich(formatted)
	else:
		print(formatted)
