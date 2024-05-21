##
## std/iter/node.gd
##
## A shared library for 'Node'-related iterators.
##
## NOTE: This 'Node' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

## An enumeration of different iteration algorithms.
enum Order { BREADTH_FIRST, DEPTH_FIRST }

## An enumeration of different iteration filters for 'Node' descendents.
enum Filter { ALL, INNER, LEAF }

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Given input arrays, returns a new array with all pairwise combinations.
static func combine(a: Array, b: Array) -> Array:
	var out := []

	var size_a := a.size()
	var size_b := b.size()

	var index_a := 0
	while index_a < size_a:
		var index_b := 0
		while index_b < size_b:
			out.append([a[index_a], b[index_b]])
			index_b += 1

		index_a += 1

	return out


## Returns an 'Array' of descendent 'Node' instances.
##
## @param node - the root node to return descendents for.
## @return - An iterator that "yields" descendent 'Node' references.
static func descendents(
	node: Node, filter: Filter = Filter.ALL, mode: Order = Order.BREADTH_FIRST
) -> Array[Node]:
	assert(node is Node, "Invalid argument; expected a 'Node'!")
	assert(mode is Order, "Invalid argument; expected an 'Order'!")
	assert(filter is Filter, "Invalid argument; expected a 'Filter'!")

	var out: Array[Node] = []

	var to_process: Array[Node] = [node]
	match mode:
		Order.BREADTH_FIRST:
			while to_process:
				var next: Node = to_process.pop_front()
				var child_count: int = next.get_child_count()

				if (
					next != node
					and (
						filter == Filter.ALL
						or (filter == Filter.INNER and child_count > 0)
						or (filter == Filter.LEAF and child_count == 0)
					)
				):
					out.append(next)

				var index: int = 0
				while index < child_count:
					to_process.append(next.get_child(index))
					index += 1

		Order.DEPTH_FIRST:
			while to_process:
				var next: Node = to_process.pop_back()
				var child_count: int = next.get_child_count()
				if (
					next != node
					and (
						filter == Filter.ALL
						or (filter == Filter.INNER and child_count > 0)
						or (filter == Filter.LEAF and child_count == 0)
					)
				):
					out.append(next)

				# Iterate in reverse order so that top-most children are first.
				var index: int = child_count - 1
				while index > -1:
					to_process.append(next.get_child(index))
					index -= 1

	return out


## Given input arrays, returns a new array with the combined elements interleaved.
static func zip(a: Array, b: Array) -> Array:
	var out := []

	var size_a := a.size()
	var size_b := b.size()

	var index: int = 0
	while index < size_a or index < size_b:
		if size_a > index:
			out.append(a[index])

		if size_b > index:
			out.append(b[index])

		index += 1

	return out


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(
		not is_inside_tree(),
		"Invalid config; this 'Node' should not be added to the 'SceneTree'!"
	)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #
