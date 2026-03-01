##
## std/fsm/state_machine_test.gd
##
## Tests pertaining to the `StdStateMachine` class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## A state that transitions to whatever path is passed as input.
class StateControllable:
	extends StdState

	func _on_input(input: NodePath) -> StdState:
		return _transition_to(input)


## A state that records lifecycle calls and transitions on input.
class StateRecording:
	extends StdState

	var enter_args: Array = []
	var exit_args: Array = []
	var update_count: int = 0

	func _on_enter(previous: StdState) -> void:
		enter_args.append(previous)

	func _on_exit(next: StdState) -> void:
		exit_args.append(next)

	func _on_input(event) -> StdState:
		return _transition_to(event)

	func _on_update(_delta: float) -> StdState:
		update_count += 1
		return null


## A basic test machine with hierarchy: A(B(C), D), E.
class TestMachine:
	extends StdStateMachine

	func _setup() -> void:
		add_state(^"A/B/C")
		add_state(^"A/D")
		add_state(^"E")

		initial = ^"A/B/C"


## A controllable test machine with the same hierarchy.
class TestMachineControllable:
	extends StdStateMachine

	func _setup() -> void:
		add_state(^"A/B/C", StateControllable.new())
		add_state(^"A/D", StateControllable.new())
		add_state(^"E", StateControllable.new())

		initial = ^"A/B/C"


## A recording test machine with the same hierarchy.
class TestMachineRecording:
	extends StdStateMachine

	func _setup() -> void:
		add_state(^"A/B/C", StateRecording.new())
		add_state(^"A/D", StateRecording.new())
		add_state(^"E", StateRecording.new())

		initial = ^"A/B/C"


## A test machine with an explicit parent state registration.
class TestMachineExplicitParent:
	extends StdStateMachine

	func _setup() -> void:
		add_state(^"A", StateControllable.new())
		add_state(^"A/B/C")
		add_state(^"A/D")
		add_state(^"E")

		initial = ^"A/B/C"


## A recording machine that also registers parent states explicitly.
class TestMachineRecordingAll:
	extends StdStateMachine

	func _setup() -> void:
		add_state(^"A", StateRecording.new())
		add_state(^"A/B", StateRecording.new())
		add_state(^"A/B/C", StateRecording.new())
		add_state(^"A/D", StateRecording.new())
		add_state(^"E", StateRecording.new())

		initial = ^"A/B/C"


## A state that attempts a nested transition during '_on_enter'.
class StateTransitionsOnEnter:
	extends StdState

	var target: NodePath

	func _on_enter(_previous: StdState) -> void:
		_transition_to(target)


## A machine with a state that triggers a nested transition.
class TestMachineNestedTransition:
	extends StdStateMachine

	func _setup() -> void:
		add_state(^"A", StateControllable.new())

		var b := StateTransitionsOnEnter.new()
		b.target = ^"A"
		add_state(^"B", b)

		initial = ^"A"


# -- TEST METHODS -------------------------------------------------------------------- #


func test_state_machine_add_state_creates_implicit_parents():
	# Given: A test machine with only leaf states registered.
	var root := TestMachine.new()

	# When: The machine enters the scene tree.
	add_child_autofree(root, true)

	# Then: Implicit parent states are created.
	assert_true(root._states.has(^"A"), "implicit parent 'A' exists")
	assert_true(root._states.has(^"A/B"), "implicit parent 'A/B' exists")

	# Then: The implicit parents are base StdState instances (not
	# a subclass like StateControllable).
	assert_eq(
		root._states[^"A"].get_script(),
		StdState,
		"implicit parent 'A' is a base StdState",
	)
	assert_eq(
		root._states[^"A/B"].get_script(),
		StdState,
		"implicit parent 'A/B' is a base StdState",
	)


func test_state_machine_add_state_explicit_parent_preserved():
	# Given: A test machine with an explicit parent registration.
	var root := TestMachineExplicitParent.new()

	# When: The machine enters the scene tree.
	add_child_autofree(root, true)

	# Then: The explicit parent keeps its custom script.
	assert_eq(
		root._states[^"A"].get_script(),
		StateControllable,
		"explicit parent 'A' keeps its script",
	)


func test_state_machine_behavioral_inheritance_delegates_to_parent():
	# Given: A machine where only explicit states handle input (base
	# StdState delegates to parent via default '_on_input').
	var root := TestMachineExplicitParent.new()
	add_child_autofree(root, true)

	# When: Input is dispatched (A is a StateControllable, so it will
	# handle the input after B and C delegate upward).
	watch_signals(root)
	root.input(^"E")

	# Then: A transition occurs (the input bubbled up to A, which
	# handled it).
	assert_signal_emit_count(root, "transition_started", 1)
	assert_signal_emitted_with_parameters(
		root, "transition_started", [^"A/B/C", ^"E"], 0
	)


func test_state_machine_enter_exit_receive_correct_states():
	# Given: A recording machine at A/B/C.
	var root := TestMachineRecording.new()
	add_child_autofree(root, true)

	var state_c: StateRecording = root._states[^"A/B/C"]
	var state_e: StateRecording = root._states[^"E"]

	# Then: The initial enter received null (no prior state).
	assert_eq(state_c.enter_args.size(), 1)
	assert_null(state_c.enter_args[0])

	# When: A transition to E is triggered.
	root.input(^"E")

	# Then: C's exit received the target state (E).
	assert_eq(state_c.exit_args.size(), 1)
	assert_eq(state_c.exit_args[0], state_e)

	# Then: E's enter received the previous leaf state (C).
	assert_eq(state_e.enter_args.size(), 1)
	assert_eq(state_e.enter_args[0], state_c)


func test_state_machine_initial_transition_emits_correct_signals():
	# Given: A test machine with initial state A/B/C.
	var root := TestMachine.new()
	watch_signals(root)

	# When: The machine enters the scene tree.
	add_child_autofree(root, true)

	# Then: No states are exited on the initial transition.
	assert_signal_emit_count(root, "state_exited", 0)

	# Then: Each state on the path to A/B/C is entered.
	assert_signal_emit_count(root, "state_entered", 3)
	assert_signal_emitted_with_parameters(root, "state_entered", [^"A"], 0)
	assert_signal_emitted_with_parameters(root, "state_entered", [^"A/B"], 1)
	assert_signal_emitted_with_parameters(root, "state_entered", [^"A/B/C"], 2)


func test_state_machine_is_in_state_updates_after_transition():
	# Given: A controllable machine at A/B/C.
	var root := TestMachineControllable.new()
	add_child_autofree(root, true)

	# When: A transition to E is triggered.
	root.input(^"E")

	# Then: The machine is no longer in the previous ancestors.
	assert_false(root.is_in_state(root._states[^"A/B/C"]))
	assert_false(root.is_in_state(root._states[^"A/B"]))
	assert_false(root.is_in_state(root._states[^"A"]))

	# Then: The machine is now in E.
	assert_true(root.is_in_state(root._states[^"E"]))


func test_state_machine_is_in_state_matches_ancestors():
	# Given: A machine at state A/B/C.
	var root := TestMachine.new()
	add_child_autofree(root, true)

	# Then: The machine reports being in the current leaf state.
	assert_true(root.is_in_state(root._states[^"A/B/C"]))

	# Then: The machine reports being in ancestor states.
	assert_true(root.is_in_state(root._states[^"A/B"]))
	assert_true(root.is_in_state(root._states[^"A"]))

	# Then: The machine reports NOT being in unrelated states.
	assert_false(root.is_in_state(root._states[^"A/D"]))
	assert_false(root.is_in_state(root._states[^"E"]))


func test_state_machine_leaf_detection_excludes_parents():
	# Given: A test machine with hierarchy A(B(C), D), E.
	var root := TestMachine.new()

	# When: The machine enters the scene tree.
	add_child_autofree(root, true)

	# Then: Leaf states are in the set; parent states are not.
	assert_true(^"A/B/C" in root._leaves, "C is a leaf")
	assert_true(^"A/D" in root._leaves, "D is a leaf")
	assert_true(^"E" in root._leaves, "E is a leaf")
	assert_false(^"A" in root._leaves, "A is not a leaf")
	assert_false(^"A/B" in root._leaves, "B is not a leaf")


func test_state_machine_parent_wiring_is_correct():
	# Given: A test machine with hierarchy A(B(C), D), E.
	var root := TestMachine.new()

	# When: The machine enters the scene tree.
	add_child_autofree(root, true)

	# Then: Top-level states have no parent.
	assert_null(root._states[^"A"]._parent)
	assert_null(root._states[^"E"]._parent)

	# Then: Nested states point to their direct parent.
	assert_eq(root._states[^"A/B"]._parent, root._states[^"A"])
	assert_eq(root._states[^"A/B/C"]._parent, root._states[^"A/B"])
	assert_eq(root._states[^"A/D"]._parent, root._states[^"A"])


func test_state_machine_reentry_reinitializes_correctly():
	# Given: A controllable machine that has transitioned to E.
	var root := TestMachineControllable.new()
	add_child(root, true)
	root.input(^"E")
	assert_eq(root.state, root._states[^"E"])

	# When: The machine is removed from the tree and re-added.
	remove_child(root)
	add_child(root, true)

	# Then: The machine reinitializes to its initial state.
	assert_eq(root.state, root._states[^"A/B/C"])

	# Then: Transitions still work after re-entry.
	root.input(^"E")
	assert_eq(root.state, root._states[^"E"])

	root.free()


func test_state_machine_transition_emits_correct_signals(
	params = use_parameters(_get_transition_params()),
):
	var target: NodePath = params[0]
	var pre_transitions: Array = params[1]
	var expected_exits: Array = params[2]
	var expected_enters: Array = params[3]

	# Given: A controllable machine at its initial state.
	var root := TestMachineControllable.new()
	add_child_autofree(root, true)

	# When: Pre-transitions are applied (if any).
	for pre: NodePath in pre_transitions:
		root.input(pre)

	var from_path := root.state._path
	watch_signals(root)

	# When: The target transition is triggered.
	root.input(target)

	# Then: The correct exit signals are emitted in order.
	assert_signal_emit_count(root, "state_exited", expected_exits.size())
	var i := 0
	while i < expected_exits.size():
		assert_signal_emitted_with_parameters(
			root, "state_exited", [expected_exits[i]], i
		)
		i += 1

	# Then: The correct enter signals are emitted in order.
	assert_signal_emit_count(root, "state_entered", expected_enters.size())
	var j := 0
	while j < expected_enters.size():
		assert_signal_emitted_with_parameters(
			root, "state_entered", [expected_enters[j]], j
		)
		j += 1

	# Then: Transition start/finish signals wrap the transition.
	assert_signal_emit_count(root, "transition_started", 1)
	assert_signal_emitted_with_parameters(
		root, "transition_started", [from_path, target], 0
	)
	assert_signal_emit_count(root, "transition_finished", 1)
	assert_signal_emitted_with_parameters(
		root, "transition_finished", [from_path, target], 0
	)


func test_state_machine_transition_updates_current_state():
	# Given: A controllable machine at A/B/C.
	var root := TestMachineControllable.new()
	add_child_autofree(root, true)

	# Then: The initial state is set.
	assert_eq(root.state, root._states[^"A/B/C"])

	# When: A transition to E is triggered.
	root.input(^"E")

	# Then: The current state is updated.
	assert_eq(root.state, root._states[^"E"])

	# When: A second transition to A/D is triggered.
	root.input(^"A/D")

	# Then: The current state is updated again.
	assert_eq(root.state, root._states[^"A/D"])


func test_state_machine_update_delegates_to_current_state():
	# Given: A recording machine at A/B/C.
	var root := TestMachineRecording.new()
	add_child_autofree(root, true)

	var state_c: StateRecording = root._states[^"A/B/C"]
	var state_e: StateRecording = root._states[^"E"]

	# When: The machine is updated.
	root.update(0.016)

	# Then: The current state received the update.
	assert_eq(state_c.update_count, 1)
	assert_eq(state_e.update_count, 0)

	# When: A transition occurs and the machine is updated again.
	root.input(^"E")
	root.update(0.016)

	# Then: Only the new current state received the update.
	assert_eq(state_c.update_count, 1)
	assert_eq(state_e.update_count, 1)


func test_state_machine_parent_exit_receives_correct_target():
	# Given: A recording machine (with explicit parents) at A/B/C.
	var root := TestMachineRecordingAll.new()
	add_child_autofree(root, true)

	var state_a: StateRecording = root._states[^"A"]
	var state_b: StateRecording = root._states[^"A/B"]
	var state_e: StateRecording = root._states[^"E"]

	# When: A transition to E is triggered.
	root.input(^"E")

	# Then: Parent states A/B and A received '_on_exit' with the
	# target state (E).
	assert_eq(state_b.exit_args.size(), 1)
	assert_eq(state_b.exit_args[0], state_e)
	assert_eq(state_a.exit_args.size(), 1)
	assert_eq(state_a.exit_args[0], state_e)


func test_state_machine_unhandled_input_terminates_cleanly():
	# Given: A machine with base StdState leaves (default '_on_input'
	# delegates to parent, which eventually returns null at the root).
	var root := TestMachine.new()
	add_child_autofree(root, true)

	var before := root.state

	# When: Input is dispatched.
	root.input(^"E")

	# Then: No crash occurs and the state is unchanged (base StdState
	# does not handle transitions).
	assert_eq(root.state, before)


func test_state_machine_transition_to_empty_path_logs_error():
	# Given: A controllable machine at A/B/C.
	var root := TestMachineControllable.new()
	add_child_autofree(root, true)

	var before := root.state

	# When: A transition to an empty path is requested.
	root.input(NodePath())

	# Then: An error is logged.
	assert_push_error("Missing transition target path.")

	# Then: The state is unchanged.
	assert_eq(root.state, before)


func test_state_machine_transition_to_unregistered_path_logs_error():
	# Given: A controllable machine at A/B/C.
	var root := TestMachineControllable.new()
	add_child_autofree(root, true)

	var before := root.state

	# When: A transition to an unregistered path is requested.
	root.input(^"Z")

	# Then: An error is logged.
	assert_push_error("Transition target not found.")

	# Then: The state is unchanged.
	assert_eq(root.state, before)


func test_state_machine_transition_to_non_leaf_logs_error():
	# Given: A controllable machine at A/B/C.
	var root := TestMachineControllable.new()
	add_child_autofree(root, true)

	var before := root.state

	# When: A transition to a non-leaf state is requested.
	root.input(^"A")

	# Then: An error is logged.
	assert_push_error("Transition target is not a leaf state.")

	# Then: The state is unchanged.
	assert_eq(root.state, before)


func test_state_machine_nested_transition_logs_error():
	# Given: A machine where state B triggers a transition on enter.
	var root := TestMachineNestedTransition.new()
	add_child_autofree(root, true)

	# When: A transition from A to B is triggered. B's '_on_enter'
	# attempts a nested transition back to A.
	root.input(^"B")

	# Then: The nested transition attempt logged an error.
	assert_push_error("Nested transitions prohibited.")

	# Then: The original transition completed (state is B), and the
	# nested transition was rejected.
	assert_eq(root.state, root._states[^"B"])


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Parameterized transition scenarios. Each entry contains:
## [target, pre_transitions, expected_exits, expected_enters].
func _get_transition_params() -> Array:
	return [
		# Cross-tree: deep to shallow (LCA is root).
		[^"E", [], [^"A/B/C", ^"A/B", ^"A"], [^"E"]],
		# Self-transition (LCA is parent A/B).
		[^"A/B/C", [], [^"A/B/C"], [^"A/B/C"]],
		# Sibling with unequal depth (LCA is A).
		[^"A/D", [], [^"A/B/C", ^"A/B"], [^"A/D"]],
		# Reverse: shallow to deep (LCA is root).
		[^"A/B/C", [^"E"], [^"E"], [^"A", ^"A/B", ^"A/B/C"]],
	]
