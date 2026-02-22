##
## std/logging/level.gd
##
## Defines the log severity levels used throughout the logging pipeline.
##

# -- DEFINITIONS --------------------------------------------------------------------- #

## Level enumerates the possible logging levels.
enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

const LEVEL_DEBUG := Level.DEBUG
const LEVEL_INFO := Level.INFO
const LEVEL_WARN := Level.WARN
const LEVEL_ERROR := Level.ERROR

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## level_name maps a level value to its human-readable name.
static func level_name(level: Level) -> String:
	match level:
		LEVEL_DEBUG:
			return "DEBUG"
		LEVEL_INFO:
			return "INFO"
		LEVEL_WARN:
			return "WARN"
		LEVEL_ERROR:
			return "ERROR"
		_:
			assert(false, "invalid argument; unknown log level: %d" % level)
			return "UNKNOWN"
