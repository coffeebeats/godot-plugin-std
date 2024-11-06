##
## std/setting/sync_target_file.gd
##
## `StdSettingsSyncTargetFile` specifies that the configuration should be synced to a
## binary file at the specified path.
##

class_name StdSettingsSyncTargetFile
extends StdSettingsSyncTarget

# -- CONFIGURATION ------------------------------------------------------------------- #

## path is a path to a file in which the 'StdSettingsScope' contents will be synced to.
@export var path: String = ""

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_sync_target_node() -> StdConfigWriter:
	var writer := StdBinaryConfigWriter.new()
	writer.path = path

	return writer
