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
signal state_entered(path: NodePath)

## Emitted when a 'State' is exited.
signal state_exited(path: NodePath)

## Emitted when a 'State' transition is started.
signal transition_started(from: NodePath, to: NodePath)

## Emitted when a 'State' transition is finished.
signal transition_finished(from: NodePath, to: NodePath)

# -- DEFINITIONS --------------------------------------------------------------------- #

enum StateMachineProcessCallback {
	STATE_MACHINE_PROCESS_PHYSICS = 0, STATE_MACHINE_PROCESS_IDLE = 1
}

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Iterators := preload("../iter/node.gd")
const State := preload("state.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## The starting 'State' for the 'StateMachine'; will be transitioned to on 'ready'.
@export_node_path var initial: NodePath

## Whether to "compact" the 'StateMachine' by extracting 'State' scripts as 'Object'
## instances from each child 'Node'.
@export var compact: bool = true

## process_callback determines whether 'update' is called during the physics or idle
## process callback function (if the process mode allows for it).
@export
var process_callback := StateMachineProcessCallback.STATE_MACHINE_PROCESS_PHYSICS:
	set(value):
		process_callback = value

		match value:
			StateMachineProcessCallback.STATE_MACHINE_PROCESS_PHYSICS:
				set_physics_process(true)
				set_process(false)
			StateMachineProcessCallback.STATE_MACHINE_PROCESS_IDLE:
				set_physics_process(false)
				set_process(true)

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create("std/fsm/state-machine")  # gdlint:ignore=class-definitions-order,max-line-length

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
	assert(initial, "invalid configuration; missing 'initial' property")

	# Iterate through all 'State' nodes
	for n in Iterators.descendents(
		self, Iterators.Filter.ALL, Iterators.Order.DEPTH_FIRST
	):
		var s: State

		if compact:
			s = _extract_state(n)
		else:
			s = (n as Object) as State

		if s == null:
			continue

		assert(s != null, "child node is not a valid state")

		var p := n.get_parent()
		s._parent = _states[get_path_to(p)] if p and p != self else null
		s._path = get_path_to(n)
		s._root = self

		_leaves[s.get_instance_id()] = s
		_states[get_path_to(n)] = s

		_logger.debug("Registered state.", {&"path": str(s._path)})

	# Delete 'Node' instances to prevent their addition to the scene.
	if compact:
		var index := 0
		while index < get_child_count():
			var child := get_child(index)
			remove_child(child)
			child.free()


func _notification(what) -> void:
	if compact and what == NOTIFICATION_PREDELETE:
		state = null
		for s in _states.values():
			if is_instance_valid(s):
				s.free()


func _physics_process(delta) -> void:
	update(delta)


func _process(delta) -> void:
	update(delta)


func _ready() -> void:
	# Trigger the setter to properly configure callback functions.
	process_callback = process_callback

	# Transition to the initial 'State'
	_transition_to(initial)
	assert(state is State, "failed to set initial 'State'")
	assert(
		_leaves.has(state.get_instance_id()),
		"invalid configuration; 'initial' is not a leaf 'State'"
	)


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
		assert(not strict, "failed to extract 'State' from 'Node'")
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
	assert(path != NodePath(), "missing argument: path")

	# If possible, normalize the provided path.
	if not compact:
		var target = get_node_or_null(path)
		assert(target is State, "invalid argument; 'path' is not a State node")

		path = get_path_to(target as Object as Node)

	assert(path in _states, "Invalid argument; 'path' not found in 'StateMachine'!")
	assert(not _is_in_transition, "Invalid config; nested transitions prohibited!")

	_logger.info("Transitioning to state.", {&"path": str(path)})

	var next: State = _states[path]
	assert(next.get_instance_id() in _leaves, "Argument 'next' was not a leaf 'State'!")

	var from_path := state._path if state else NodePath()
	var to_path := next._path

	transition_started.emit(from_path, to_path)

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

	transition_finished.emit(from_path, to_path)
