##
## router/history_test.gd
##
## Tests for StdRouterHistory stack data structure.
##

extends GutTest

# -- DEPENDENCIES ------------------------------------------------------------ #

const StdRouterHistory := preload("history.gd")
const StdRouteView := preload("route/view.gd")

# -- TEST METHODS ------------------------------------------------------------ #


func test_push_pop_lifo_order():
	# Given: A history with three pushed entries.
	var history := StdRouterHistory.new()
	var route_a := _create_route(&"a")
	var route_b := _create_route(&"b")
	var route_c := _create_route(&"c")

	history.push(route_a, null)
	history.push(route_b, null)
	history.push(route_c, null)

	# When: Entries are popped.
	var entry_c := history.pop()
	var entry_b := history.pop()
	var entry_a := history.pop()

	# Then: They come out in LIFO order.
	assert_eq(entry_c.route, route_c)
	assert_eq(entry_b.route, route_b)
	assert_eq(entry_a.route, route_a)


func test_pop_on_empty_returns_null():
	# Given: An empty history.
	var history := StdRouterHistory.new()

	# When: Pop is called.
	var entry := history.pop()

	# Then: Null is returned.
	assert_null(entry)


func test_peek_returns_topmost_without_removing():
	# Given: A history with two entries.
	var history := StdRouterHistory.new()
	var route_a := _create_route(&"a")
	var route_b := _create_route(&"b")

	history.push(route_a, null)
	history.push(route_b, null)

	# When: Peek is called.
	var entry := history.peek()

	# Then: The topmost entry is returned.
	assert_eq(entry.route, route_b)

	# Then: The size is unchanged.
	assert_eq(history.size(), 2)


func test_peek_on_empty_returns_null():
	# Given: An empty history.
	var history := StdRouterHistory.new()

	# When: Peek is called.
	var entry := history.peek()

	# Then: Null is returned.
	assert_null(entry)


func test_is_empty_reflects_state():
	# Given: An empty history.
	var history := StdRouterHistory.new()
	assert_true(history.is_empty())

	# When: An entry is pushed.
	history.push(_create_route(&"a"), null)

	# Then: is_empty returns false.
	assert_false(history.is_empty())

	# When: The entry is popped.
	history.pop()

	# Then: is_empty returns true.
	assert_true(history.is_empty())


func test_size_tracks_correctly():
	# Given: An empty history.
	var history := StdRouterHistory.new()
	assert_eq(history.size(), 0)

	# When: Entries are pushed.
	history.push(_create_route(&"a"), null)
	assert_eq(history.size(), 1)

	history.push(_create_route(&"b"), null)
	assert_eq(history.size(), 2)

	# When: An entry is popped.
	history.pop()

	# Then: Size decreases.
	assert_eq(history.size(), 1)


func test_clear_empties_stack():
	# Given: A history with entries.
	var history := StdRouterHistory.new()
	history.push(_create_route(&"a"), null)
	history.push(_create_route(&"b"), null)
	assert_eq(history.size(), 2)

	# When: Clear is called.
	history.clear()

	# Then: The stack is empty.
	assert_true(history.is_empty())
	assert_eq(history.size(), 0)


func test_entries_returns_correct_order():
	# Given: A history with entries pushed in order.
	var history := StdRouterHistory.new()
	var route_a := _create_route(&"a")
	var route_b := _create_route(&"b")
	var route_c := _create_route(&"c")

	history.push(route_a, null)
	history.push(route_b, null)
	history.push(route_c, null)

	# When: Entries are retrieved.
	var result := history.entries()

	# Then: They are in push order (bottom to top).
	assert_eq(result.size(), 3)
	assert_eq(result[0].route, route_a)
	assert_eq(result[1].route, route_b)
	assert_eq(result[2].route, route_c)


func test_push_preserves_params():
	# Given: A history.
	var history := StdRouterHistory.new()
	var route := _create_route(&"a")
	var params := StdRouteParams.new()

	# When: An entry is pushed with params.
	history.push(route, params)

	# Then: The entry preserves the params.
	var entry := history.peek()
	assert_eq(entry.params, params)


func test_push_with_null_params():
	# Given: A history.
	var history := StdRouterHistory.new()
	var route := _create_route(&"a")

	# When: An entry is pushed with null params.
	history.push(route, null)

	# Then: The entry has null params.
	var entry := history.peek()
	assert_eq(entry.route, route)
	assert_null(entry.params)


func test_pop_all_leaves_empty():
	# Given: A history with multiple entries.
	var history := StdRouterHistory.new()
	history.push(_create_route(&"a"), null)
	history.push(_create_route(&"b"), null)
	history.push(_create_route(&"c"), null)

	# When: All entries are popped.
	history.pop()
	history.pop()
	history.pop()

	# Then: The history is empty.
	assert_true(history.is_empty())
	assert_eq(history.size(), 0)

	# Then: Another pop returns null.
	assert_null(history.pop())


func test_entries_on_empty_returns_empty_array():
	# Given: An empty history.
	var history := StdRouterHistory.new()

	# When: Entries are retrieved.
	var result := history.entries()

	# Then: An empty array is returned.
	assert_eq(result.size(), 0)


func test_clear_then_push_works():
	# Given: A history that was populated and then cleared.
	var history := StdRouterHistory.new()
	history.push(_create_route(&"a"), null)
	history.push(_create_route(&"b"), null)
	history.clear()

	# When: A new entry is pushed after clear.
	var route := _create_route(&"c")
	history.push(route, null)

	# Then: The history works normally.
	assert_eq(history.size(), 1)
	assert_eq(history.peek().route, route)


# -- PRIVATE METHODS --------------------------------------------------------- #


func _create_route(segment: StringName) -> StdRouteView:
	var route := StdRouteView.new()
	route.segment = segment
	route.name = str(segment)
	return route
