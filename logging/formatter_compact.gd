##
## std/logging/formatter_compact.gd
##
## StdLogFormatterCompact produces single-line plain text log messages with no
## BBCode markup. This is the default formatter and works in all environments.
##

class_name StdLogFormatterCompact
extends StdLogFormatter

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func format(
	name: StringName, level: int, ts: float, msg: String, ctx: Dictionary
) -> String:
	var prefix := str(name, " ") if name else ""
	var out := str(
		Time.get_datetime_string_from_unix_time(int(ts)),
		" ",
		prefix,
		LogLevels.level_name(level),
		" ",
		msg,
	)

	for key in ctx:
		out += str(" ", key, "=", ctx[key])

	return out
