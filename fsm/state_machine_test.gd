##
## Tests pertaining to the 'StateMachine' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const State := preload("state.gd")
const StateMachine := preload("state_machine.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #


class StateControllable:
	extends State

	func _on_input(input: NodePath) -> State:
		return _transition_to(input)


# -- TEST METHODS -------------------------------------------------------------------- #


func test_state_machine_compaction_removes_children_when_added_to_scene_tree():
	var root := _create_state_machine(^"A/B/C")
	watch_signals(root)

	# Trigger 'StateMachine' "compaction" process.
	add_child_autofree(root)

	# No states are exited on the initial transition.
	assert_eq(root.get_child_count(), 0)


func test_state_machine_initial_transition_emits_correct_signals():
	var root := _create_state_machine(^"A/B/C")
	watch_signals(root)

	# Trigger 'StateMachine' "compaction" process.
	add_child_autofree(root)

	# No states are exited on the initial transition.
	assert_signal_emit_count(root, "state_exit", 0)

	# Each 'State' on the path to 'A/B/C' is entered.
	assert_signal_emit_count(root, "state_enter", 3)
	assert_signal_emitted_with_parameters(root, "state_enter", [^"A"], 0)
	assert_signal_emitted_with_parameters(root, "state_enter", [^"A/B"], 1)
	assert_signal_emitted_with_parameters(root, "state_enter", [^"A/B/C"], 2)


func test_state_machine_transition_emits_correct_signals():
	var root := _create_state_machine(^"A/B/C", StateControllable)

	# Trigger 'StateMachine' "compaction" process.
	add_child_autofree(root)

	# Ignore signals from initial transition
	watch_signals(root)

	# Trigger a transition to 'E'.
	root.input(^"E")

	# Each 'State' on the path from 'A/B/C' is exited.
	assert_signal_emit_count(root, "state_exit", 3)
	assert_signal_emitted_with_parameters(root, "state_exit", [^"A/B/C"], 0)
	assert_signal_emitted_with_parameters(root, "state_exit", [^"A/B"], 1)
	assert_signal_emitted_with_parameters(root, "state_exit", [^"A"], 2)

	# Each 'State' on the path to 'E' is entered.
	assert_signal_emit_count(root, "state_enter", 1)
	assert_signal_emitted_with_parameters(root, "state_enter", [^"E"], 0)


func test_state_machine_self_transition_emits_correct_signals():
	var root := _create_state_machine(^"A/B/C", StateControllable)

	# Trigger 'StateMachine' "compaction" process.
	add_child_autofree(root)

	# Ignore signals from initial transition
	watch_signals(root)

	# Trigger a transition to 'A/B/C'.
	root.input(^"A/B/C")

	# Only 'A/B/C' is exited.
	assert_signal_emit_count(root, "state_exit", 1)
	assert_signal_emitted_with_parameters(root, "state_exit", [^"A/B/C"], 0)

	# Only 'A/B/C' is (re-)entered.
	assert_signal_emit_count(root, "state_enter", 1)
	assert_signal_emitted_with_parameters(root, "state_enter", [^"A/B/C"], 0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Creates a simple 'StateMachine' for testing, structured as follows:
##
## Root (StateMachine, initial=E)
## 	'-> A (State)
## 		'-> B (State)
## 			'-> C (State)
## 		'-> D (State)
## 	'-> E (State)
##
## @args:
## 	initial - A 'NodePath' pointing to the starting 'State'
## 	state - The script to use for 'State' objects
func _create_state_machine(initial: NodePath, state: GDScript = State) -> StateMachine:
	var out := StateMachine.new()

	var nodes: Dictionary = {}
	for n in ["A", "B", "C", "D", "E"]:
		var node := Node.new()
		node.name = n
		node.set_script(state)
		nodes[n] = node

	nodes["B"].add_child(nodes["C"], true)
	nodes["A"].add_child(nodes["B"], true)
	nodes["A"].add_child(nodes["D"], true)

	out.add_child(nodes["A"], true)
	out.add_child(nodes["E"], true)

	out.initial = initial

	return out
