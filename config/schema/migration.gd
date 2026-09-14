##
## std/config/schema/migration.gd
##
## StdConfigSchemaMigration is a base class for schema migrations. Subclasses override
## `_migrate()` to transform raw `Config` data between schema versions.
##

class_name StdConfigSchemaMigration
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## version_from is a schema version identifier that this migration must run on to make
## data compatible with the next schema version.
##
## For example, if version `5` renamed a property, `version_from` might be set to `4`
## and the migration function would execute the rename on the provided `Config` object.
@export var version_from: int = 0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _migrate(_config: Config) -> void:
	assert(false, "unimplemented; must override the '_migrate' method.")
