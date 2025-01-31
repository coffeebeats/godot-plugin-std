##
## std/statistic/store.gd
##
## StdStatStoreSteam is a Steam-backed stats store implementation.
##

@tool
class_name StdStatStoreSteam
extends StdStatStore

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _load_stats() -> void:
	pass


func _store_stats() -> bool:
	return Steam.storeStats()
