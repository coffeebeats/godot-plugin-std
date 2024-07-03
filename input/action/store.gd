##
## std/input/action/store.gd
##
## InputActionStore ...
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## list_actions returns the list of action sets defined for the game.
func list_action_sets() -> Array[StringName]:
    return []

## list_actions returns the list of actions defined for the specified action set.
func list_actions(action_set: StringName) -> Array[StringName]:
    assert(action_set in list_action_sets(), "invalid input; unknown action set")
    return []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #