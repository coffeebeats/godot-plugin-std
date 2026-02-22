##
## std/logging/profile.gd
##
## StdLogProfile bundles a log level, per-category level overrides, a formatter, and a
## sink into a single exportable resource. Profiles can be saved as `.tres` files and
## applied at runtime to configure the logging pipeline.
##

class_name StdLogProfile
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LogLevels := preload("level.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Severity")

## level is the global log level threshold applied by this profile.
@export var level: LogLevels.Level = LogLevels.LEVEL_WARN

## level_overrides maps category prefixes to their per-category log level overrides.
## Logger names matching a prefix (via `begins_with()`) will use the corresponding level
## instead of the global one.
@export var level_overrides: Dictionary[String, LogLevels.Level] = {}

## formatter is the log formatter applied by this profile. If unset, the current
## formatter is left unchanged.
@export var formatter: StdLogFormatter

## sink is the log sink applied by this profile. If unset, the current sink is left
## unchanged.
@export var sink: StdLogSink

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_and_apply loads a profile from disk and applies it. Does nothing if the file
## does not exist.
static func load_and_apply(path: String) -> void:
	if not ResourceLoader.exists(path):
		return

	var profile: StdLogProfile = ResourceLoader.load(path)
	if not profile is StdLogProfile:
		assert(false, "invalid argument; expected a 'StdLogProfile' resource")
		return

	profile.apply()


## apply copies this profile's settings into `StdLogger`'s static state. Previous
## category level overrides are cleared before applying new ones.
func apply() -> void:
	StdLogger.set_level(level)

	StdLogger.clear_all_category_levels()
	for prefix in level_overrides:
		StdLogger.set_category_level(prefix, level_overrides[prefix])

	if formatter:
		StdLogger.set_formatter(formatter)
	if sink:
		StdLogger.set_sink(sink)
