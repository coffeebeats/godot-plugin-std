##
## std/save/summary.gd
##
## StdSaveSummary is a base class for the schema defining a summary of one save's
## progress. This contains metadata about the progress, rather than the progress itself.
##

class_name StdSaveSummary
extends StdConfigItem

# -- CONFIGURATION ------------------------------------------------------------------- #

## time_last_saved is the last time (unix epoch timestamp) this save slot was saved.
@export var time_last_saved: float = 0.0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	return "summary"
