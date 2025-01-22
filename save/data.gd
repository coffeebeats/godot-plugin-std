##
## std/save/data.gd
##
## StdSaveData is a base class for defining the schema of the game's save data (for a
## single save slot).
##

class_name StdSaveData
extends StdConfigSchema

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## summary is a save summary resource which defines the metadata about this save.
@export var summary: StdSaveSummary = null
