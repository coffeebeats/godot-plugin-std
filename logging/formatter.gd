##
## std/logging/formatter.gd
##
## StdLogFormatter is the base class for log message formatters and can be extended to
## customize the format of log output.
##
## NOTE: Formatters are output-agnostic; they should not emit any logs or warnings.
##

class_name StdLogFormatter
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LogLevels := preload("level.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## bbcode indicates whether the formatted output contains BBCode markup. Sinks may use
## this flag to decide how to output the log content.
@export var bbcode: bool = false

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


## format produces a single-line string representation of the given log data.
##
## NOTE: This method should be overridden to customize log output.
func format(_name: StringName, _level: int, _msg: String, _ctx: Dictionary) -> String:
	return ""
