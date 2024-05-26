##
## std/scene/transition.gd
##
## Transition ...
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

signal done

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## replace is an absolute 'NodePath' to the 'Node' to remove from the 'SceneTree'.
@export var replace: NodePath

## next is the loaded scene with which to swap the to-be-replaced 'Node' with.
@export var next: PackedScene

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start_transition() -> Error:
	assert(false, "unimplemented")
	return FAILED


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _done() -> void:
	done.emit()

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
