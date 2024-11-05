##
## std/setting/sync_target.gd
##
## StdSettingsSyncTarget defines a storage location to sync configuration to.
##

class_name StdSettingsSyncTarget
extends Resource

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_sync_target_node creates a `StdConfigWriter` node that can be used to sync
## configuration to storage.
func create_sync_target_node() -> StdConfigWriter:
	return _create_sync_target_node()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_sync_target_node() -> StdConfigWriter:
	assert(false, "unimplemented")
	return null
