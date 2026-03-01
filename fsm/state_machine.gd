##
## std/fsm/state_machine.gd
##
## A hierarchical state machine (HSM) implementation. States are registered via
## `add_state()` during the `_setup()` virtual. Only the machine itself is a `Node`;
## states are `RefCounted` (`StdState`) instances.
##
## Implementation is heavily adapted from interpretation of [Introduction to
## Hierarchical State Machines](
## https://barrgroup.com/embedded-systems/how-to/introduction-hierarchical-state-machines).
##

@icon("../editor/icons/state_machine.svg")
class_name StdStateMachine
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## Emitted when a state is entered.
signal state_entered(path: NodePath)

## Emitted when a state is exited.
signal state_exited(path: NodePath)

## Emitted when a state transition is started.
signal transition_started(from: NodePath, to: NodePath)

## Emitted when a state transition is finished.
signal transition_finished(from: NodePath, to: NodePath)

# -- DEFINITIONS --------------------------------------------------------------------- #

## StateMachineProcessCallback enumerates the Godot engine callback during which states
## will tick.
enum StateMachineProcessCallback {
	PROCESS_PHYSICS = 0,
	PROCESS_IDLE = 1,
}

const STATE_MACHINE_PROCESS_PHYSICS := StateMachineProcessCallback.PROCESS_PHYSICS
const STATE_MACHINE_PROCESS_IDLE := StateMachineProcessCallback.PROCESS_IDLE

# -- CONFIGURATION ------------------------------------------------------------------- #

## The starting state path for the machine; set during '_setup()'.
@export var initial: NodePath

## Determines whether 'update' is called during the physics or idle
## process callback function (if the process mode allows for it).
@export var process_callback := STATE_MACHINE_PROCESS_PHYSICS:
	set(value):
		process_callback = value

		match value:
			STATE_MACHINE_PROCESS_PHYSICS:
				set_physics_process(true)
				set_process(false)
			STATE_MACHINE_PROCESS_IDLE:
				set_physics_process(false)
				set_process(true)

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/fsm/state-machine")  # gdlint:ignore=class-definitions-order,max-line-length

## A pointer to the currently active state.
var state: StdState = null

## A flag denoting whether the machine is currently in a transition.
var _is_in_transition: bool = false

## A set of leaf state paths (NodePath -> bool).
var _leaves: Dictionary = {}

## A mapping of NodePath -> StdState for all registered states.
var _states: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Registers a state at the given path. If no instance is provided, a base `StdState` is
## created. Called during '_setup()'.
func add_state(
	path: NodePath,
	instance: StdState = null,
) -> StdState:
	assert(path != NodePath(), "invalid argument: missing path")
	assert(
		not path.is_absolute(),
		"invalid argument: path must be relative",
	)
	assert(
		path not in _states,
		"invalid argument: path '%s' already registered" % str(path),
	)

	var s: StdState = instance if instance else StdState.new()
	s._path = path
	_states[path] = s
	return s


## Dispatches input to the current state. States may return their parent to delegate
## handling up the hierarchy.
func input(event) -> void:
	var target: StdState = state
	while target:
		target = target._on_input(event)  # gdlint:ignore=private-method-call


## Returns whether the machine is currently in the specified state. This is true if the
## specified state is a super-state of the current leaf.
func is_in_state(other: StdState) -> bool:
	assert(
		other is StdState,
		"invalid argument: expected 'other' to be a 'StdState'",
	)
	return state != null and state.is_substate_of(other)


## Executes the next frame/tick of the machine (delegates to the current state). States
## may return their parent to delegate processing up the hierarchy.
func update(delta: float) -> void:
	var target: StdState = state
	while target:
		target = target._on_update(delta)  # gdlint:ignore=private-method-call


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: Tree removal does NOT fire exit callbacks on active states. This is
	# deliberate — tree removal is not a state transition.
	# Clear prior state to support scene tree re-entry.
	state = null
	_states.clear()
	_leaves.clear()
	_is_in_transition = false

	# Allow subclasses to register states.
	_setup()

	assert(initial != NodePath(), "invalid configuration: missing 'initial'")

	# Create implicit parent states for any registered path with more than one segment.
	# Explicit registrations are never overwritten.
	var paths := _states.keys().duplicate()
	for path: NodePath in paths:
		var count := path.get_name_count()
		var depth := 1
		while depth < count:
			var parent_path := _subpath(path, depth)
			if parent_path not in _states:
				var s := StdState.new()
				s._path = parent_path
				_states[parent_path] = s
			depth += 1

	# Wire `_parent` pointers now that all states exist.
	var parents := {}
	for path: NodePath in _states:
		var s: StdState = _states[path]
		if path.get_name_count() > 1:
			var parent_path := _subpath(path, path.get_name_count() - 1)
			s._parent = _states[parent_path]
			parents[parent_path] = true

	# Connect `transition_requested` on each state.
	for path: NodePath in _states:
		var s: StdState = _states[path]
		s.transition_requested.connect(_transition_to)

	# Compute the leaf set: any state that is not a parent.
	for path: NodePath in _states:
		if path not in parents:
			_leaves[path] = true

	assert(initial in _states, "invalid configuration: 'initial' not registered")
	assert(
		initial in _leaves,
		"invalid configuration: 'initial' is not a leaf state",
	)

	# Ensure `_ready()` re-fires on tree re-entry.
	request_ready()


func _notification(what) -> void:
	if what == NOTIFICATION_PREDELETE:
		state = null
		_states.clear()
		_leaves.clear()


func _physics_process(delta) -> void:
	update(delta)


func _process(delta) -> void:
	update(delta)


func _ready() -> void:
	# Trigger the setter to properly configure callback functions.
	process_callback = process_callback

	# Transition to the initial state.
	_transition_to(initial)
	assert(state is StdState, "failed to set initial state")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## Called during `_enter_tree()`. Override to register states via `add_state()` and set
## the `initial` path.
func _setup() -> void:
	pass


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Returns the first `depth` segments of a `NodePath`.
static func _subpath(path: NodePath, depth: int) -> NodePath:
	assert(depth > 0, "invalid argument: depth must be positive")
	assert(
		depth <= path.get_name_count(),
		"invalid argument: depth exceeds path segment count",
	)

	var parts: PackedStringArray = []
	var i := 0
	while i < depth:
		parts.append(path.get_name(i))
		i += 1

	return NodePath("/".join(parts))


## Handles state transition lifecycle given the target path.
func _transition_to(path: NodePath) -> void:
	if path == NodePath():
		_logger.error("Missing transition target path.")
		return

	if path not in _states:
		_logger.error("Transition target not found.", {&"path": str(path)})
		return

	if _is_in_transition:
		(
			_logger
			. error(
				"Nested transitions prohibited.",
				{
					&"current": str(state._path) if state else "",
					&"requested": str(path),
				}
			)
		)
		return

	if path not in _leaves:
		_logger.error("Transition target is not a leaf state.", {&"path": str(path)})
		return

	var next: StdState = _states[path]
	var from_path := state._path if state else NodePath()
	var to_path := next._path

	_logger.info(
		"Transitioning to state.", {&"from": str(from_path), &"to": str(to_path)}
	)

	transition_started.emit(from_path, to_path)

	var to_exit := [state] if state else []
	var to_enter := [next]

	# Compute the least common ancestor (LCA). Exit and enter states up to, but not
	# including, the LCA. Level depths first so the lockstep walk aligns correctly.
	var exiting: StdState = state._parent if state else null
	var entering: StdState = next._parent

	var exit_depth := exiting._path.get_name_count() if exiting else 0
	var enter_depth := entering._path.get_name_count() if entering else 0

	while exit_depth > enter_depth:
		to_exit.append(exiting)
		exiting = exiting._parent
		exit_depth -= 1

	while enter_depth > exit_depth:
		to_enter.append(entering)
		entering = entering._parent
		enter_depth -= 1

	while exiting != entering:
		if exiting:
			to_exit.append(exiting)
			exiting = exiting._parent
		if entering:
			to_enter.append(entering)
			entering = entering._parent

	_is_in_transition = true

	# Exit states from current leaf up to (but not including) the LCA.
	var i := 0
	var size_to_exit := to_exit.size()
	while i < size_to_exit:
		var s: StdState = to_exit[i]
		s._on_exit(next)  # gdlint:ignore=private-method-call
		state_exited.emit(s._path)
		i += 1

	# NOTE: `state` is updated between exit and enter phases. During exits,
	# `machine.state` references the old leaf; during enters, the new leaf.
	var previous: StdState = state
	state = next

	# Enter states from inner non-common ancestor down to the target.
	var j := to_enter.size() - 1
	while j > -1:
		var s: StdState = to_enter[j]
		s._on_enter(previous)  # gdlint:ignore=private-method-call
		state_entered.emit(s._path)
		j -= 1

	_is_in_transition = false

	transition_finished.emit(from_path, to_path)
