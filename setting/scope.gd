##
## std/setting/scope.gd
##
## StdSettingsScope provides users a way to reference a `Config` instance by simply
## loading the 'Resource'. In this way all uses of this 'Resource', which will share the
## same instance, can refer to the same `Config` object.
##

@tool
class_name StdSettingsScope
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## config is a `Config` instance that contains configuration values for the scope.
var config: Config = Config.new()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_repository returns a reference to a settings repository hosting this scope, if
## one exists.
func get_repository() -> StdSettingsRepository:
	var members := StdGroup.with_id(get_scope_id()).list_members()
	assert(members.size() <= 1, "invalid state: found multiple repositories")

	return null if members.is_empty() else members[0]


## get_scope_id returns the unique identifier for this scope.
##
## NOTE: This value is tied to the scope's instance - it will be different for multiple
## instances of this scope. As such, a 'StdSettingsScope' is intended to be loaded from
## disk, ensuring all consumers share the same instance.
func get_scope_id() -> String:
	return str(get_instance_id())


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _setup_local_to_scene() -> void:
	assert(false, "resource should not be duplicated")
