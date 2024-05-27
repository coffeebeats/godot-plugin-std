##
## std/scene/switcher/transition/instant.gd
##
## Instant is an implementation of 'Transition' which instantly transitions to the new
## scene by first removing the previous node and then adding the new node.
##

extends "../transition.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## duration is the length of the fade in/out animation.
@export_range(0.0, 3.0) var duration: float = 1.5

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _start_transition() -> Error:
    call_deferred("_impl")
    return OK
    
# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _impl() -> void:
    _change_scene()
    _done()

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
