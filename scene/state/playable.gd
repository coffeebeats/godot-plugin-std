##
## std/scene/state/playable.gd
##
## Playable is a state which inherits from 'Instantiable'. It's primary use is the
## simple case of loading a scene, instantiating it, and then adding it to the scene
## tree.
##

extends "instantiable.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TransitionEvent := preload("../event/transition.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Actions")

## action_set is an action set to load once this playable state is entered.
##
## NOTE: This action set will be loaded for *all* input slots that exist. As such, more
## complex requirements would be better served by in-scene action set loading.
@export var action_set: StdInputActionSet = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _node: Node = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## set_node allows for a caller to provide a reference to the node this state would
## otherwise load, instantiate and add to the scene.
##
## NOTE: This is only intended to be called by other states which manage the node
## instantiation, like specific 'Transition' state implementations.
func set_node(node: Node) -> void:
	assert(node, "missing input; node does not exist")
	assert(not _node, "node already exists; cannot replace existing node reference")
	assert(not _root.is_in_state(self), "cannot pass node reference while active")

	_node = node


# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(_previous: State) -> void:
	if not _node and not scene.is_empty():
		_load_result = _get_loader().load(scene)

	if action_set:
		assert(action_set is StdInputActionSet, "invalid config; wrong type")
		assert(not action_set is StdInputActionSetLayer, "invalid config; wrong type")

		for slot in StdInputSlot.all():
			slot.load_action_set(action_set)


## A virtual method called when leaving this state (prior to entering next state).
func _on_exit(next: State) -> void:
	super(next)

	_node = null


## A virtual method called to process 'StateMachine' input for the current frame.
func _on_input(event: Event) -> State:
	if event is TransitionEvent:
		if not _node:
			return _parent

		var target := _root.get_node_or_null(event.target)
		assert(target, "missing transition target")

		var transition := target as Object as State
		assert(transition, "invalid transition target; must be a scene state")

		return _transition_to(event.target)

	return _parent


## A virtual method called to process a frame/tick, given the frame time 'delta'.
func _on_update(_delta: float) -> State:
	if not _node:
		assert(_load_result != null, "missing load result")
		assert(_load_result.get_error() == OK, "failed to load resource")

		if _load_result.status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return _parent

		assert(_load_result.scene, "missing scene on load result")
		_node = _load_result.scene.instantiate()

	if not _node.is_inside_tree():
		var path_with_fallback: NodePath = _root.game_root
		if not path.is_empty():
			path_with_fallback = path

		# gdlint:ignore=private-method-call
		_root._add_node_to_scene(path_with_fallback, _node, Mode.SCENE_MODE_REPLACE)

	return _parent
