##
## std/fsm/state_machine.gd
##
## Generic Hierarchical State Machine implementation. Initializes states, defined via
## children State nodes, and delegates engine callbacks to the active state.
##
## Implementation is heavily adapted from interpretation of [Introduction to
## Heirarchical State Machines](
## https://barrgroup.com/embedded-systems/how-to/introduction-hierarchical-state-machines).
##
## NOTE: This 'StateMachine' node is assembled as a "scene", with child 'State' nodes
## being added in nested fashion to denote hierarchical relations. Howver, once the
## 'StateMachine' node enters the 'SceneTree', it will "compact" its form into a single
## 'Node' instance (itself). This is done by extracting the 'Object'-extended 'State'
## implementation from each descendent 'Node'. The descendent nodes are then removed and
## freed prior to them entering the 'SceneTree'.

@icon("../editor/icons/state_machine.svg")
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## Emitted when a 'State' is entered.
signal state_entered(next)

## Emitted when a 'State' is exited.
signal state_exited(previous)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Iterators := preload("../iter/node.gd")
const State := preload("state.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## The starting 'State' for the 'StateMachine'; will be transitioned to on 'ready'.
@export_node_path var initial: NodePath

# -- INITIALIZATION ------------------------------------------------------------------ #

## A pointer to the currently active 'State'.
var state: State = null

## A flag denoting whether the 'StateMachine' is currently in a 'State' transition.
var _is_in_transition: bool = false

## A mapping of 'int'->'State' objects.
var _leaves: Dictionary = {}

## A mapping of 'NodePath'->'State' objects.
var _states: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Dispatches 'StateMachine' events to the current 'State' node.
##
## NOTE: 'State' nodes may return a pointer to their parent node. In that case,
## this 'StateMachine' node needs to dispatch the event to the parent node.
##
## @args:
## 	event - the 'StateMachine' event to process
func input(event) -> void:
	var target: State = state
	while target:
		target = target._on_input(event)  # gdlint:ignore=private-method-call


## Returns whether the 'StateMachine' is currently in the specified 'State'. This can be
## true if the specified 'State' is a super-state of the current leaf 'State'.
##
## @args:
## 	other - the super-'State' node to check.
func is_in_state(other: State) -> bool:
	assert(other is State, "Invalid argument; expected 'other' to be a 'State'!")
	return state.is_substate_of(other)


## Execute the next frame/tick of the 'StateMachine' (delegates to current 'State').
##
## NOTE: 'State' objects may return a pointer to their parent node. In that case, this
## 'StateMachine' node needs to dispatch the event to the parent node.
##
## @args:
## 	delta - the elapsed time since the last frame/tick
func update(delta: float) -> void:
	var target: State = state
	while target:
		target = target._on_update(delta)  # gdlint:ignore=private-method-call


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(initial, "Invalid configuration; missing 'initial' property!")

	# Iterate through all 'State' nodes
	for n in Iterators.descendents(
		self, Iterators.Filter.ALL, Iterators.Order.DEPTH_FIRST
	):
		var s := _extract_state(n)

		var p := n.get_parent()
		s._parent = _states[get_path_to(p)] if p and p != self else null
		s._path = get_path_to(n)
		s._root = self

		_leaves[s.get_instance_id()] = s
		_states[get_path_to(n)] = s

	# Delete 'Node' instances to prevent their addition to the scene.
	var index := 0
	while index < get_child_count():
		var child := get_child(index)
		remove_child(child)
		child.free()

	# Transition to the initial 'State'
	_transition_to(initial)
	assert(state is State, "Failed to set initial 'State'!")
	assert(
		_leaves.has(state.get_instance_id()),
		"Invalid configuration; 'initial' is not a leaf 'State'!"
	)


func _notification(what) -> void:
	if what == NOTIFICATION_PREDELETE:
		state = null
		for s in _states.values():
			if is_instance_valid(s):
				s.free()


# NOTE: To disable auto-'update' calls, set 'process_mode' to 'PROCESS_MODE_DISABLED'.
func _physics_process(delta) -> void:
	update(delta)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Extracts a 'State' object from a 'Node' with a 'State' script attached. Also
## populates the returned object with correctly-set export variables.
func _extract_state(node: Node, strict: bool = true) -> State:
	var s: Script = node.get_script()
	while s:
		if s == State:
			break

		s = s.get_base_script()

	if not s is Script:
		assert(not strict, "Failed to extract 'State' from 'Node'!")
		return null

	var out: State = node.get_script().new()
	for p in node.get_script().get_script_property_list():
		var p_name: String = p["name"]
		var p_usage: PropertyUsageFlags = p["usage"]

		# Need to populate export variables with the editor-defined values.
		if p_usage & PROPERTY_USAGE_STORAGE:
			out.set(p_name, node.get(p_name))

	return out


## Handles state transition lifecycle given the current and next states.
##
## @args:
## 	path [NodePath] - A 'NodePath' (relative to 'StateMachine') to the target 'State'.
func _transition_to(path: NodePath) -> void:
	assert(path in _states, "Invalid argument; 'path' not found in 'StateMachine'!")
	assert(not _is_in_transition, "Invalid config; nested transitions prohibited!")

	var next: State = _states[path]
	assert(next.get_instance_id() in _leaves, "Argument 'next' was not a leaf 'State'!")

	var to_exit := [state] if state else []
	var to_enter := [next]

	# The specification states that '_on_enter'/'_on_exit' methods should be called on
	# all states up to, but *not* including, the least common ancestor. This means we
	# need to prune common ancestors from the "path".
	var exiting: State = state._parent if state else null
	var entering: State = next._parent
	while exiting != entering:
		if exiting:
			to_exit.append(exiting)
			exiting = exiting._parent
		if entering:
			to_enter.append(entering)
			entering = entering._parent

	_is_in_transition = true

	# First, exit states; proceed from current 'state' up until the common ancestor.
	var i := 0
	var size_to_exit := to_exit.size()
	while i < size_to_exit:
		var s: State = to_exit[i]
		s._on_exit(next)  # gdlint:ignore=private-method-call
		state_exited.emit(s._path)
		i += 1

	# Then, update the current 'state' value.
	var previous: State = state
	state = next

	# Finally, enter states; proceed from inner non-common ancestor 'State' to 'next'.
	var j := to_enter.size() - 1
	while j > -1:
		var s: State = to_enter[j]
		s._on_enter(previous)  # gdlint:ignore=private-method-call
		state_entered.emit(s._path)
		j -= 1

	_is_in_transition = false

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
