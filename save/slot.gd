##
## std/save/slot.gd
##
## StdSaveSlot defines metadata for a specific save slot.
##

class_name StdSaveSlot
extends StdConfigItem

# -- INITIALIZATION ------------------------------------------------------------------ #

@export_category("Metadata")

## index is a save slot number (i.e. a namespace) under which progress will be saved.
@export var index: int = 0

## checksum is the last-known hash of the save data. This can be used to determine
## whether the associated save slot metadata needs to be reloaded.
@export var checksum: String = ""

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	return "slot-%d" % index
