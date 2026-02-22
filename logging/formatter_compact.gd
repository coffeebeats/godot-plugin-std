##
## std/logging/formatter_compact.gd
##
## StdLogFormatterCompact produces single-line plain text log messages with no
## BBCode markup. This is the default formatter and works in all environments.
##

class_name StdLogFormatterCompact
extends StdLogFormatter

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func format(name: StringName, level: int, msg: String, ctx: Dictionary) -> String:
	var out: String

	if name:
		out = str(name, " ", LogLevels.level_name(level), " ", msg)
	else:
		out = str(LogLevels.level_name(level), " ", msg)

	for key in ctx:
		out += str(" ", key, "=", ctx[key])

	return out
