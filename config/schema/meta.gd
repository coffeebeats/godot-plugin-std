##
## std/config/schema/meta.gd
##
## StdConfigSchemaMeta is an internal config item that stores schema version metadata.
##

extends StdConfigItem

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var version: int = 0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	return &"__meta__"
