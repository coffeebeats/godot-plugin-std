##
## std/scene/handle.gd
##
## Handle is a Node type which the root node of a scene *must* inherit. This class
## provides functionality for requesting scene changes and other scene-related queries.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Scene := preload("scene.gd")
const TransitionEvent := preload("event/transition.gd")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## transition_to transitions the 'Scene' state machine to the state specified by 'path'.
func transition_to(path: NodePath, data: Resource = null) -> void:
	var event := TransitionEvent.new()
	event.target = path
	event.data = data

	var nodes := get_tree().get_nodes_in_group(Scene._GROUP_SCENE_FSM)
	assert(len(nodes) == 1, "unexpected number of scene FSM nodes")

	var scene = nodes[0] as Scene
	assert(scene is Scene, "invalid 'Scene' state machine node")

	scene.input(event)
