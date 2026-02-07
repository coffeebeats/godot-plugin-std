##
## router/layer_test.gd
##
## Tests for StdRouterLayer per-navigator state management.
##

extends GutTest

# -- DEPENDENCIES ------------------------------------------------------------ #

const StdRouterLayer := preload("layer.gd")
const StdRouteModal := preload("route/modal.gd")
const StdRouteView := preload("route/view.gd")

# -- TEST METHODS ------------------------------------------------------------ #


func test_push_state_saves_current_to_history():
	# Given: A layer with a current route.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	layer.set_current(route_a, null)

	# When: A new route is pushed.
	var route_b := _create_view(&"b")
	layer.push_state(route_b, null)

	# Then: The current route is updated.
	assert_eq(layer.current_route, route_b)

	# Then: The previous route is in history.
	assert_true(layer.can_pop())
	assert_eq(layer.history.peek().route, route_a)


func test_pop_state_pops_history_and_sets_new():
	# Given: A layer with history.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	var route_b := _create_view(&"b")
	layer.set_current(route_a, null)
	layer.push_state(route_b, null)

	# When: Pop state is called with route_a.
	layer.pop_state(route_a, null)

	# Then: The current route is updated.
	assert_eq(layer.current_route, route_a)

	# Then: History is empty.
	assert_false(layer.can_pop())


func test_set_current_does_not_touch_history():
	# Given: A layer with a current route.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	layer.set_current(route_a, null)

	# When: set_current is called with a new route.
	var route_b := _create_view(&"b")
	layer.set_current(route_b, null)

	# Then: The current route is updated.
	assert_eq(layer.current_route, route_b)

	# Then: History remains empty.
	assert_false(layer.can_pop())


func test_clear_resets_everything():
	# Given: A layer with current route and history.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	var route_b := _create_view(&"b")
	layer.set_current(route_a, null)
	layer.push_state(route_b, null)
	assert_true(layer.can_pop())

	# When: Clear is called.
	layer.clear()

	# Then: Everything is reset.
	assert_null(layer.current_route)
	assert_null(layer.current_params)
	assert_false(layer.can_pop())


func test_is_base_when_no_root_route():
	# Given: A layer with no root_route.
	var layer := StdRouterLayer.new()

	# Then: is_base returns true.
	assert_true(layer.is_base())


func test_is_base_returns_false_with_root_route():
	# Given: A layer with a root_route.
	var layer := StdRouterLayer.new()
	layer.root_route = _create_modal(&"modal")

	# Then: is_base returns false.
	assert_false(layer.is_base())


func test_can_pop_reflects_history_state():
	# Given: An empty layer.
	var layer := StdRouterLayer.new()
	assert_false(layer.can_pop())

	# When: A route is pushed.
	var route_a := _create_view(&"a")
	layer.set_current(route_a, null)
	layer.push_state(_create_view(&"b"), null)

	# Then: can_pop returns true.
	assert_true(layer.can_pop())


func test_get_view_beneath_modal_skips_modals():
	# Given: A layer with a view, then a modal in history.
	var layer := StdRouterLayer.new()
	var view := _create_view(&"view")
	var modal := _create_modal(&"modal")

	layer.set_current(view, null)
	layer.push_state(modal, null)

	# When: get_view_beneath_modal is called.
	var result := layer.get_view_beneath_modal()

	# Then: The view is returned (not the modal).
	assert_eq(result, view)


func test_get_view_beneath_modal_returns_null_if_none():
	# Given: A layer with only modals in history.
	var layer := StdRouterLayer.new()
	var modal_a := _create_modal(&"a")
	var modal_b := _create_modal(&"b")

	layer.set_current(modal_a, null)
	layer.push_state(modal_b, null)

	# When: get_view_beneath_modal is called.
	var result := layer.get_view_beneath_modal()

	# Then: Null is returned.
	assert_null(result)


func test_collect_routes_returns_current_plus_history():
	# Given: A layer with current and history entries.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	var route_b := _create_view(&"b")
	var route_c := _create_view(&"c")

	layer.set_current(route_a, null)
	layer.push_state(route_b, null)
	layer.push_state(route_c, null)

	# When: collect_routes is called.
	var routes := layer.collect_routes()

	# Then: Current is first, then history top-to-bottom.
	assert_eq(routes.size(), 3)
	assert_eq(routes[0], route_c)
	assert_eq(routes[1], route_b)
	assert_eq(routes[2], route_a)


func test_push_state_preserves_params():
	# Given: A layer with a current route and params.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	var params_a := StdRouteParams.new()
	layer.set_current(route_a, params_a)

	# When: A new route is pushed with new params.
	var route_b := _create_view(&"b")
	var params_b := StdRouteParams.new()
	layer.push_state(route_b, params_b)

	# Then: Current params are updated.
	assert_eq(layer.current_params, params_b)

	# Then: Previous params are preserved in history.
	assert_eq(layer.history.peek().params, params_a)


func test_init_with_custom_history():
	# Given: A pre-populated history.
	var history := StdRouterHistory.new()
	var route := _create_view(&"a")
	history.push(route, null)

	# When: A layer is created with that history.
	var layer := StdRouterLayer.new(history)

	# Then: The layer uses the provided history.
	assert_eq(layer.history, history)
	assert_true(layer.can_pop())
	assert_eq(layer.history.peek().route, route)


func test_push_state_from_null_current():
	# Given: A fresh layer with no current route.
	var layer := StdRouterLayer.new()
	assert_null(layer.current_route)

	# When: A route is pushed.
	var route := _create_view(&"a")
	layer.push_state(route, null)

	# Then: The current route is set.
	assert_eq(layer.current_route, route)

	# Then: Nothing was added to history (null current skipped).
	assert_false(layer.can_pop())


func test_pop_state_on_empty_history():
	# Given: A layer with no history.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	layer.set_current(route_a, null)
	assert_false(layer.can_pop())

	# When: pop_state is called despite empty history.
	var route_b := _create_view(&"b")
	layer.pop_state(route_b, null)

	# Then: The current route is updated.
	assert_eq(layer.current_route, route_b)

	# Then: History is still empty.
	assert_false(layer.can_pop())


func test_collect_routes_deduplicates():
	# Given: A layer where the current route also appears in history.
	var layer := StdRouterLayer.new()
	var route_a := _create_view(&"a")
	var route_b := _create_view(&"b")

	# Manually set up: a in history, push b, then set current back to a.
	layer.set_current(route_a, null)
	layer.push_state(route_b, null)
	# Now current=b, history=[a]. Set current to a (simulating redirect).
	layer.current_route = route_a

	# When: collect_routes is called.
	var routes := layer.collect_routes()

	# Then: Each route appears only once.
	assert_eq(routes.size(), 2)
	assert_eq(routes[0], route_a)
	assert_eq(routes[1], route_b)


func test_collect_routes_empty_layer():
	# Given: A layer with no current route and no history.
	var layer := StdRouterLayer.new()

	# When: collect_routes is called.
	var routes := layer.collect_routes()

	# Then: An empty array is returned.
	assert_eq(routes.size(), 0)


func test_get_view_beneath_modal_deep_mixed_stack():
	# Given: A layer with view, modal, view, modal in history.
	var layer := StdRouterLayer.new()
	var view_a := _create_view(&"view_a")
	var modal_a := _create_modal(&"modal_a")
	var view_b := _create_view(&"view_b")
	var modal_b := _create_modal(&"modal_b")

	layer.set_current(view_a, null)
	layer.push_state(modal_a, null)
	layer.push_state(view_b, null)
	layer.push_state(modal_b, null)

	# When: get_view_beneath_modal is called.
	var result := layer.get_view_beneath_modal()

	# Then: The most recent non-modal (view_b) is returned.
	assert_eq(result, view_b)


func test_get_view_beneath_modal_empty_history():
	# Given: A layer with a current route but empty history.
	var layer := StdRouterLayer.new()
	layer.set_current(_create_modal(&"modal"), null)

	# When: get_view_beneath_modal is called.
	var result := layer.get_view_beneath_modal()

	# Then: Null is returned (history is empty).
	assert_null(result)


func test_clear_preserves_root_route():
	# Given: A modal layer with a root_route.
	var layer := StdRouterLayer.new()
	var modal := _create_modal(&"root")
	layer.root_route = modal
	layer.set_current(_create_view(&"child"), null)
	layer.push_state(_create_view(&"other"), null)

	# When: Clear is called.
	layer.clear()

	# Then: root_route is preserved (clear only resets nav state).
	assert_eq(layer.root_route, modal)
	assert_null(layer.current_route)
	assert_false(layer.can_pop())


# -- PRIVATE METHODS --------------------------------------------------------- #


func _create_view(segment: StringName) -> StdRouteView:
	var route := StdRouteView.new()
	route.segment = segment
	route.name = str(segment)
	return route


func _create_modal(segment: StringName) -> StdRouteModal:
	var route := StdRouteModal.new()
	route.segment = segment
	route.name = str(segment)
	return route
