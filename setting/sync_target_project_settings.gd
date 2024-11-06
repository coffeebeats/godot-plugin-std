##
## std/setting/sync_target_project_settings.gd
##
## `StdSettingsSyncTargetProjectSettings` specifies that configuration should be synced
## to the project's project settings override file.
##

class_name StdSettingsSyncTargetProjectSettings
extends StdSettingsSyncTarget

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_sync_target_node() -> StdConfigWriter:
	var writer := StdProjectSettingsConfigWriter.new()

	return writer
