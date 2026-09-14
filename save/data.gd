##
## std/save/data.gd
##
## StdSaveData is a base class for defining the schema of the game's save data (for a
## single save slot).
##

class_name StdSaveData
extends StdConfigSchema

# -- CONFIGURATION ------------------------------------------------------------------- #

## summary is a save summary resource which defines the metadata about this save.
@export var summary: StdSaveSummary = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## store populates the provided `Config` instance with this save data's items, auto-
## setting the last saved timestamp.
func store(config: Config) -> void:
	_compute_summary()
	super.store(config)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _compute_summary is a virtual method called to derive summary state before saving.
func _compute_summary() -> void:
	if not summary is StdSaveSummary:
		assert(false, "invalid state; missing save data summary")
		return

	summary.time_last_saved = Time.get_unix_time_from_system()
