##
## std/scene/state/transition.gd
##
## Transition is a base class for various transition implementations. This state should
## *not* be added to the 'Scene' state machine directly.
##

extends "../scene.gd".State

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Scene := preload("../scene.gd")
const Instantiable := preload("instantiable.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## to is the node path from this state to the state to which this node will transition.
@export var to: NodePath

# -- INITIALIZATION ------------------------------------------------------------------ #

var _to_load_result: Loader.Result = null

# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(previous: State) -> void:
	super(previous)

	var node: Node = self as Object as Node

	var target: Scene.State = node.get_node_or_null(to) as Object
	assert(target, "missing target state node; must be a scene state")

	if target is Instantiable:
		_to_load_result = _get_loader().load(target.scene)


## A virtual method called when leaving this state (prior to entering next state).
func _on_exit(next: State) -> void:
	super(next)

	_to_load_result = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_target() -> Node:
	var node: Node = self as Object as Node
	assert(node, "invalid configuration; not a node")

	return node.get_node_or_null(to) as Object
