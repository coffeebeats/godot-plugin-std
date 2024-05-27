##
## std/scene/runner/state.gd
##
## State ...
##

extends "../../fsm/state.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Loader := preload("../loader.gd")
const Switcher := preload("../switcher/switcher.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene is a path to a scene file with which to run when in this state.
@export_file var scene: String

## transition is preloaded 'Transition' node with which to transition the active node.
@export var transition: PackedScene = null

## dependencies are paths to other states which this node might transition to or
## otherwise depends on. Dependent scenes listed here will begin background loading
## once this state is entered.
@export var dependencies: Array[NodePath] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
