##
## Tests pertaining to 'Iterators' methods.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Iterators := preload("node.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## To facilitate testing iterators, the following scene will be constructed prior to
## each test:
##
## Root (Node)
## 	'-> A (Node)
##    '-> B (Node)
##      '-> C (Node)
##    '-> D (Node)
## 	'-> E (Node)
var scene: Node

# -- TEST METHODS -------------------------------------------------------------------- #


func test_combine_correctly_produces_new_array(
	params = use_parameters(
		[
			[[1, 2], [1, 2], [[1, 1], [1, 2], [2, 1], [2, 2]]],
			[[], [1, 2, 3], []],
			[[1, 2, 3], [1], [[1, 1], [2, 1], [3, 1]]],
		]
	)
):
	assert_eq(Iterators.combine(params[0], params[1]), params[2])


func test_descendents_returns_correct_nodes(
	params = use_parameters(
		Iterators.combine(Iterators.Order.values(), Iterators.Filter.values())
	)
) -> void:
	var order: Iterators.Order = params[0]
	var filter: Iterators.Filter = params[1]

	var nodes: Array[String] = []
	for node in Iterators.descendents(scene, filter, order):
		nodes.append(node.name)

	match params:
		[Iterators.Order.BREADTH_FIRST, Iterators.Filter.ALL]:
			assert_eq("".join(nodes), "AEBDC")
		[Iterators.Order.BREADTH_FIRST, Iterators.Filter.INNER]:
			assert_eq("".join(nodes), "AB")
		[Iterators.Order.BREADTH_FIRST, Iterators.Filter.LEAF]:
			assert_eq("".join(nodes), "EDC")
		[Iterators.Order.DEPTH_FIRST, Iterators.Filter.ALL]:
			assert_eq("".join(nodes), "ABCDE")
		[Iterators.Order.DEPTH_FIRST, Iterators.Filter.INNER]:
			assert_eq("".join(nodes), "AB")
		[Iterators.Order.DEPTH_FIRST, Iterators.Filter.LEAF]:
			assert_eq("".join(nodes), "CDE")


func test_zip_correctly_orders_interleaves_input_arrays(
	params = use_parameters(
		[
			[[1, 2, 3], [1, 2, 3], [1, 1, 2, 2, 3, 3]],
			[[], [1, 2, 3], [1, 2, 3]],
			[[1, 2, 3], [], [1, 2, 3]],
		]
	)
):
	assert_eq(Iterators.zip(params[0], params[1]), params[2])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	var root := Node.new()

	var nodes: Dictionary = {}
	for n in ["A", "B", "C", "D", "E"]:
		var node := Node.new()
		node.name = n
		nodes[n] = node

	nodes["B"].add_child(nodes["C"], true)
	nodes["A"].add_child(nodes["B"], true)
	nodes["A"].add_child(nodes["D"], true)

	root.add_child(nodes["A"], true)
	root.add_child(nodes["E"], true)

	scene = root
	add_child_autofree(scene)

# -- PRIVATE METHODS ----------------------------------------------------------------- #
