##
## router/hook/save_data.gd
##
## A route lifecycle hook that manages save data persistence during navigation. Note
## that this hook simplifies wiring up the lifecycle management, but requires the user
## to implement `_load_data` and `_save_data`.
##

class_name StdRouteHookSaveData
extends StdRouteHook

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Lifecycle")

## load_before_enter controls whether to load save data when entering the route. Note
## that failing to load will block the navigation attempt.
@export var load_before_enter: bool = true

## save_before_exit controls whether to store save data when exiting the route. Note
## that failing to save will block the navigation attempt.
@export var save_before_exit: bool = true

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _before_enter(ctx: StdRouteContext) -> Result:
	var result := Result.new()

	if not load_before_enter:
		return result

	if _load_data(ctx) != OK:
		result.action = Result.ACTION_BLOCK
		return result

	return result


func _before_exit(ctx: StdRouteContext) -> Result:
	var result := Result.new()

	if not save_before_exit:
		return result

	if _save_data(ctx) != OK:
		result.action = Result.ACTION_BLOCK
		return result

	return result


## _load_data is a virtual method responsible for loading save game data.
##
## NOTE: The user must override this method.
func _load_data(_context: StdRouteContext) -> Error:
	assert(false, "unimplemented; this method must be overridden.")
	return OK


## _save_data is a virtual method responsible for saving game data.
##
## NOTE: The user must override this method.
func _save_data(_context: StdRouteContext) -> Error:
	assert(false, "unimplemented; this method must be overridden.")
	return OK
