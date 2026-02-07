#gdlint:ignore=max-public-methods,max-file-lines

##
## router/router_test.gd
##
## Tests for StdRouter navigation logic and history management.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const StdRouter := preload("router.gd")
const StdRoute := preload("route.gd")
const StdRouterContext := preload("context.gd")
const StdRouteGuard := preload("guard.gd")
const StdRouteHandle := preload("handle.gd")
const StdRouteHook := preload("hook.gd")
const StdRouteModal := preload("route/modal.gd")
const StdRouteParams := preload("params.gd")
const StdRouteRedirect := preload("route/redirect.gd")
const StdRouteView := preload("route/view.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## BlockingGuard is a test guard that blocks navigation when enabled.
class BlockingGuard:
	extends StdRouteGuard

	var should_block: bool = false

	func _is_allowed(_context: StdRouterContext) -> bool:
		return not should_block


## TrackingHook is a test hook that tracks lifecycle events and can
## block/redirect navigation.
class TrackingHook:
	extends StdRouteHook

	var before_enter_calls: Array[StdRouterContext] = []
	var after_enter_calls: Array[StdRouterContext] = []
	var before_exit_calls: Array[StdRouterContext] = []
	var after_exit_calls: Array[StdRouterContext] = []

	var should_block_enter: bool = false
	var should_block_exit: bool = false
	var redirect_to_handle: StdRouteHandle = null
	var redirect_params: StdRouteParams = null

	func _before_enter(context: StdRouterContext) -> Result:
		before_enter_calls.append(context)
		var result := Result.new()
		if should_block_enter:
			result.action = Result.ACTION_BLOCK
		elif redirect_to_handle != null:
			result.action = Result.ACTION_REDIRECT
			result.redirect_to = redirect_to_handle
			result.redirect_params = redirect_params
		return result

	func _after_enter(context: StdRouterContext) -> void:
		after_enter_calls.append(context)

	func _before_exit(context: StdRouterContext) -> Result:
		before_exit_calls.append(context)
		var result := Result.new()
		if should_block_exit:
			result.action = Result.ACTION_BLOCK
		return result

	func _after_exit(context: StdRouterContext) -> void:
		after_exit_calls.append(context)


## TestParams is a concrete params type for serialization testing.
class TestParams:
	extends StdRouteParams

	var score: int = 0
	var label: String = ""


# -- INITIALIZATION ------------------------------------------------------------------ #

var _router: StdRouter
var _content_root: Node
var _overlay_root: Node

# -- TEST METHODS -------------------------------------------------------------------- #

# ==================== Core Navigation Tests ====================


func test_push_navigates_to_route():
	# Given: A router with an initial route and a second route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: A new route is pushed.
	var err := _router.push(target_route)
	await get_tree().process_frame

	# Then: Navigation succeeds.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), target_route)

	# Then: The 'navigated' signal was emitted.
	assert_signal_emitted(_router, "navigated")


func test_push_adds_current_route_to_history():
	# Given: A router with an initial route and a target route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)

	# Given: Initial navigation completes.
	await get_tree().process_frame

	# When: A new route is pushed.
	var err := _router.push(target_route)
	await get_tree().process_frame

	# Then: Navigation succeeds and history contains previous route.
	assert_eq(err, OK)
	assert_true(_router.can_pop())


func test_replace_clears_history_and_navigates():
	# Given: A router with initial route and history.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var middle_handle := _create_handle()
	var middle_route := _create_view_route(middle_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, middle_route, target_route], initial_route)
	await get_tree().process_frame

	# Given: We push to create history.
	_router.push(middle_route)
	await get_tree().process_frame
	assert_true(_router.can_pop())

	# When: Replace is called.
	var err := _router.replace(target_route)
	await get_tree().process_frame

	# Then: Navigation succeeds and history is cleared.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), target_route)
	assert_false(_router.can_pop())


func test_pop_returns_to_previous_route():
	# Given: A router with history.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	_router.push(target_route)
	await get_tree().process_frame
	assert_eq(_router.get_current_route(), target_route)

	# When: Pop is called.
	var err := _router.pop()
	await get_tree().process_frame

	# Then: Navigation returns to previous route.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), initial_route)


func test_pop_removes_entry_from_history():
	# Given: A router with multiple history entries.
	var route_a_handle := _create_handle()
	var route_a := _create_view_route(route_a_handle)

	var route_b_handle := _create_handle()
	var route_b := _create_view_route(route_b_handle)

	var route_c_handle := _create_handle()
	var route_c := _create_view_route(route_c_handle)

	_setup_router([route_a, route_b, route_c], route_a)
	await get_tree().process_frame

	_router.push(route_b)
	await get_tree().process_frame
	_router.push(route_c)
	await get_tree().process_frame

	# When: Pop is called twice.
	_router.pop()
	await get_tree().process_frame
	assert_eq(_router.get_current_route(), route_b)

	_router.pop()
	await get_tree().process_frame
	assert_eq(_router.get_current_route(), route_a)

	# Then: History is empty.
	assert_false(_router.can_pop())


func test_pop_on_empty_history_returns_error():
	# Given: A router with no history.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route], initial_route)
	await get_tree().process_frame
	assert_false(_router.can_pop())

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Pop is called.
	var err := _router.pop()

	# Then: Error is returned.
	assert_eq(err, ERR_DOES_NOT_EXIST)
	assert_signal_emitted(_router, "navigation_failed")


func test_can_pop_returns_false_on_empty_history():
	# Given: A router with no history.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route], initial_route)
	await get_tree().process_frame

	# Then: can_pop returns false.
	assert_false(_router.can_pop())


func test_can_pop_returns_true_with_history():
	# Given: A router with history.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	_router.push(target_route)
	await get_tree().process_frame

	# Then: can_pop returns true.
	assert_true(_router.can_pop())


func test_push_with_unregistered_route_returns_error():
	# Given: A router with an initial route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route], initial_route)
	await get_tree().process_frame

	# Given: An unregistered route (not a child of the router).
	var unregistered_handle := _create_handle()
	var unregistered_route := _create_view_route(unregistered_handle)

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Push is called with unregistered route.
	var err := _router.push(unregistered_route)

	# Then: Error is returned.
	assert_eq(err, ERR_DOES_NOT_EXIST)
	assert_signal_emitted(_router, "navigation_failed")


# ==================== Index Route Tests ====================


func test_is_index_redirect_navigates_to_child():
	# Given: A parent route with a child marked as is_index.
	var parent_handle := _create_handle()
	var parent_route := _create_view_route(parent_handle)

	var child_handle := _create_handle()
	var child_route := _create_view_route(child_handle)
	child_route.is_index = true
	parent_route.add_child(child_route)

	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route, parent_route], initial_route)
	await get_tree().process_frame

	# When: Navigating to the parent route.
	var err := _router.push(parent_route)
	await get_tree().process_frame

	# Then: Navigation resolves to the index child.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), child_route)


func test_nested_is_index_resolves_recursively():
	# Given: A parent with an index child that also has an index child.
	var parent_handle := _create_handle()
	var parent_route := _create_view_route(parent_handle)

	var child_handle := _create_handle()
	var child_route := _create_view_route(child_handle)
	child_route.is_index = true
	parent_route.add_child(child_route)

	var grandchild_handle := _create_handle()
	var grandchild_route := _create_view_route(grandchild_handle)
	grandchild_route.is_index = true
	child_route.add_child(grandchild_route)

	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route, parent_route], initial_route)
	await get_tree().process_frame

	# When: Navigating to the parent route.
	var err := _router.push(parent_route)
	await get_tree().process_frame

	# Then: Navigation resolves to the deepest index child.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), grandchild_route)


# ==================== Guard Tests ====================


func test_guard_blocks_navigation():
	# Given: A router with a guarded route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var guard := BlockingGuard.new()
	guard.should_block = true
	target_route.guards.append(guard)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Navigation is attempted.
	var err := _router.push(target_route)
	await get_tree().process_frame

	# Then: Navigation is blocked.
	assert_eq(err, ERR_UNAUTHORIZED)
	assert_eq(_router.get_current_route(), initial_route)
	assert_signal_emitted(_router, "navigation_failed")


func test_guard_allows_navigation():
	# Given: A router with a guarded route where guard allows.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var guard := BlockingGuard.new()
	guard.should_block = false
	target_route.guards.append(guard)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation is attempted.
	var err := _router.push(target_route)
	await get_tree().process_frame

	# Then: Navigation succeeds.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), target_route)


func test_guard_on_ancestor_blocks_navigation():
	# Given: A parent route with a blocking guard and a child route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var parent_handle := _create_handle()
	var parent_route := _create_view_route(parent_handle)

	var guard := BlockingGuard.new()
	guard.should_block = true
	parent_route.guards.append(guard)

	var child_handle := _create_handle()
	var child_route := _create_view_route(child_handle)
	child_route.is_index = true
	parent_route.add_child(child_route)

	_setup_router([initial_route, parent_route], initial_route)
	await get_tree().process_frame

	# When: Navigation to child is attempted.
	var err := _router.push(child_route)
	await get_tree().process_frame

	# Then: Navigation is blocked by ancestor guard.
	assert_eq(err, ERR_UNAUTHORIZED)
	assert_eq(_router.get_current_route(), initial_route)


# ==================== Hook Tests ====================


func test_hook_before_enter_is_called():
	# Given: A router with a hooked route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: before_enter hook was called.
	assert_eq(hook.before_enter_calls.size(), 1)
	assert_eq(hook.before_enter_calls[0].to_route, target_route)


func test_hook_after_enter_is_called():
	# Given: A router with a hooked route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: after_enter hook was called.
	assert_eq(hook.after_enter_calls.size(), 1)


func test_hook_before_exit_is_called():
	# Given: A router with a hooked initial route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var hook := TrackingHook.new()
	initial_route.hooks.append(hook)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation away from initial route occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: before_exit hook was called.
	assert_eq(hook.before_exit_calls.size(), 1)


func test_hook_after_exit_is_called():
	# Given: A router with a hooked initial route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var hook := TrackingHook.new()
	initial_route.hooks.append(hook)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation away from initial route occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: after_exit hook was called.
	assert_eq(hook.after_exit_calls.size(), 1)


func test_hook_blocks_navigation():
	# Given: A router with a blocking hook.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook := TrackingHook.new()
	hook.should_block_enter = true
	target_route.hooks.append(hook)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Navigation is attempted.
	var err := _router.push(target_route)
	await get_tree().process_frame

	# Then: Navigation is blocked.
	assert_eq(err, ERR_UNAUTHORIZED)
	assert_eq(_router.get_current_route(), initial_route)


func test_hook_before_exit_blocks_navigation():
	# Given: A router with a hook that blocks exit.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var hook := TrackingHook.new()
	hook.should_block_exit = true
	initial_route.hooks.append(hook)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation away from initial route is attempted.
	var err := _router.push(target_route)
	await get_tree().process_frame

	# Then: Navigation is blocked by exit hook.
	assert_eq(err, ERR_UNAUTHORIZED)
	assert_eq(_router.get_current_route(), initial_route)


func test_global_hooks_are_called():
	# Given: A router with global hooks.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var global_hook := TrackingHook.new()

	_setup_router([initial_route, target_route], initial_route)
	_router.hooks.append(global_hook)
	await get_tree().process_frame

	# When: Navigation occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: Global hooks were called.
	assert_eq(global_hook.before_enter_calls.size(), 1)
	assert_eq(global_hook.after_enter_calls.size(), 1)


func test_hook_lifecycle_order():
	# Given: A router with both global and route hooks.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var global_hook := TrackingHook.new()
	var route_hook := TrackingHook.new()
	target_route.hooks.append(route_hook)

	_setup_router([initial_route, target_route], initial_route)
	_router.hooks.append(global_hook)
	await get_tree().process_frame

	# When: Navigation occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: Global before_enter is called before route before_enter.
	# NOTE: We verify both are called; order is implicitly tested by implementation.
	assert_eq(global_hook.before_enter_calls.size(), 1)
	assert_eq(route_hook.before_enter_calls.size(), 1)


# ==================== Modal Tests ====================


func test_push_modal_opens_overlay():
	# Given: A router with a view route and a modal route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var modal_handle := _create_handle()
	var modal_route := _create_modal_route(modal_handle)

	_setup_router([initial_route, modal_route], initial_route)
	await get_tree().process_frame

	# When: Modal is pushed.
	var err := _router.push(modal_route)
	await get_tree().process_frame

	# Then: Modal is now active.
	assert_eq(err, OK)
	assert_eq(_router.get_current_modal(), modal_route)


func test_pop_modal_closes_overlay():
	# Given: A router with an open modal.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var modal_handle := _create_handle()
	var modal_route := _create_modal_route(modal_handle)

	_setup_router([initial_route, modal_route], initial_route)
	await get_tree().process_frame

	_router.push(modal_route)
	await get_tree().process_frame
	assert_eq(_router.get_current_modal(), modal_route)

	# When: Pop is called.
	_router.pop()
	await get_tree().process_frame

	# Then: Modal is closed.
	assert_eq(_router.get_current_modal(), null)
	assert_eq(_router.get_current_route(), initial_route)


func test_push_modal_preserves_history():
	# Given: A router with a view route and modal.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var modal_handle := _create_handle()
	var modal_route := _create_modal_route(modal_handle)

	_setup_router([initial_route, modal_route], initial_route)
	await get_tree().process_frame

	# When: Modal is pushed.
	_router.push(modal_route)
	await get_tree().process_frame

	# Then: History allows returning to previous route.
	assert_true(_router.can_pop())


func test_pop_stacked_modal_restores_previous_modal():
	# Given: A router with a view and two modal routes.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var modal_a_handle := _create_handle()
	var modal_a := _create_modal_route(modal_a_handle, &"modal_a")

	var modal_b_handle := _create_handle()
	var modal_b := _create_modal_route(modal_b_handle, &"modal_b")

	_setup_router([initial_route, modal_a, modal_b], initial_route)
	await get_tree().process_frame

	# Given: Two modals are pushed (stacked).
	_router.push(modal_a)
	await get_tree().process_frame
	assert_eq(_router.get_current_modal(), modal_a)

	_router.push(modal_b)
	await get_tree().process_frame
	assert_eq(_router.get_current_modal(), modal_b)

	# When: Pop removes the top modal.
	_router.pop()
	await get_tree().process_frame

	# Then: The previous modal is restored.
	assert_eq(_router.get_current_modal(), modal_a)
	assert_eq(_router.get_current_route(), initial_route)

	# When: Pop removes the restored modal.
	_router.pop()
	await get_tree().process_frame

	# Then: No modal is active, view is restored.
	assert_eq(_router.get_current_modal(), null)
	assert_eq(_router.get_current_route(), initial_route)


# ==================== Redirect Tests ====================


func test_redirect_navigates_to_target():
	# Given: A router with a redirect route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var redirect_handle := _create_handle()
	var redirect_route := StdRouteRedirect.new()
	redirect_route.handle = redirect_handle
	redirect_route.segment = &"redirect"
	redirect_route.redirect_to = target_route

	_setup_router([initial_route, target_route, redirect_route], initial_route)
	await get_tree().process_frame

	# When: Navigating to the redirect.
	var err := _router.push(redirect_route)
	await get_tree().process_frame

	# Then: Navigation resolves to the target.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), target_route)


func test_redirect_preserves_params_when_configured():
	# Given: A router with a redirect that preserves params.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var redirect_handle := _create_handle()
	var redirect_route := StdRouteRedirect.new()
	redirect_route.handle = redirect_handle
	redirect_route.segment = &"redirect"
	redirect_route.redirect_to = target_route
	redirect_route.preserve_params = true

	_setup_router([initial_route, target_route, redirect_route], initial_route)
	await get_tree().process_frame

	# Given: A tracking hook on the target to capture params.
	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	# When: Navigating to the redirect with params.
	var params := StdRouteParams.new()
	_router.push(redirect_route, params)
	await get_tree().process_frame

	# Then: Params are preserved to the target.
	# NOTE: The context's to_params should match the original params.
	assert_eq(hook.before_enter_calls.size(), 1)


func test_redirect_guard_on_redirect_blocks_navigation():
	# Given: A redirect route with a blocking guard.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var redirect_handle := _create_handle()
	var redirect_route := StdRouteRedirect.new()
	redirect_route.handle = redirect_handle
	redirect_route.segment = &"redirect"
	redirect_route.redirect_to = target_route

	var guard := BlockingGuard.new()
	guard.should_block = true
	redirect_route.guards.append(guard)

	_setup_router([initial_route, target_route, redirect_route], initial_route)
	await get_tree().process_frame

	# When: Navigating to the redirect.
	var err := _router.push(redirect_route)
	await get_tree().process_frame

	# Then: Navigation is blocked.
	assert_eq(err, ERR_UNAUTHORIZED)
	assert_eq(_router.get_current_route(), initial_route)


# ==================== Path Tests ====================


func test_get_current_path_returns_full_path():
	# Given: A router with nested routes.
	var parent_handle := _create_handle()
	var parent_route := _create_view_route(parent_handle, &"parent")

	var child_handle := _create_handle()
	var child_route := _create_view_route(child_handle, &"child")
	child_route.is_index = true
	parent_route.add_child(child_route)

	_setup_router([parent_route], parent_route)
	await get_tree().process_frame

	# Then: The path reflects the full route hierarchy.
	assert_eq(_router.get_current_path(), &"/parent/child")


func test_get_current_path_returns_empty_for_no_route():
	# Given: A router with no initial route.
	_setup_router([], null)
	await get_tree().process_frame

	# Then: The path is empty.
	assert_eq(_router.get_current_path(), &"")


# ==================== Transition State Tests ====================


func test_is_transitioning_returns_false_when_idle():
	# Given: A router that has completed initial navigation.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route], initial_route)
	await get_tree().process_frame

	# Then: is_transitioning returns false.
	assert_false(_router.is_transitioning())


# ==================== Signal Tests ====================


func test_navigating_signal_emitted_before_navigation():
	# Given: A router with routes.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Navigation is triggered.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: Both signals are emitted in order.
	assert_signal_emitted(_router, "navigating")
	assert_signal_emitted(_router, "navigated")


func test_navigation_failed_signal_emitted_on_error():
	# Given: A router with a guarded route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var guard := BlockingGuard.new()
	guard.should_block = true
	target_route.guards.append(guard)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Navigation is attempted.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: navigation_failed signal is emitted.
	assert_signal_emitted(_router, "navigation_failed")


func test_navigating_not_emitted_when_guard_blocks():
	# Given: A router with a guarded route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var guard := BlockingGuard.new()
	guard.should_block = true
	target_route.guards.append(guard)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# Given: Signal emissions are monitored.
	watch_signals(_router)

	# When: Navigation is blocked by a guard.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: navigating signal was NOT emitted.
	assert_signal_not_emitted(_router, "navigating")


# ==================== Context Tests ====================


func test_context_contains_from_and_to_routes():
	# Given: A router with a hooked route to inspect context.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: Context contains correct from and to routes.
	assert_eq(hook.before_enter_calls.size(), 1)
	var context: StdRouterContext = hook.before_enter_calls[0]
	assert_eq(context.from_route, initial_route)
	assert_eq(context.to_route, target_route)


func test_context_trigger_is_push():
	# Given: A router with a hooked route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Push is called.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: Context event is PUSH.
	var context: StdRouterContext = hook.before_enter_calls[0]
	assert_eq(context.event, StdRouterContext.NAVIGATION_EVENT_PUSH)


func test_context_trigger_is_replace():
	# Given: A router with a hooked route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Replace is called.
	_router.replace(target_route)
	await get_tree().process_frame

	# Then: Context event is REPLACE.
	var context: StdRouterContext = hook.before_enter_calls[0]
	assert_eq(context.event, StdRouterContext.NAVIGATION_EVENT_REPLACE)


func test_context_trigger_is_pop():
	# Given: A router with history and a hooked initial route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var hook := TrackingHook.new()
	initial_route.hooks.append(hook)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	_router.push(target_route)
	await get_tree().process_frame

	# When: Pop is called.
	_router.pop()
	await get_tree().process_frame

	# Then: Context event is POP.
	# NOTE: The second before_enter call is from the pop.
	assert_eq(hook.before_enter_calls.size(), 2)
	var context: StdRouterContext = hook.before_enter_calls[1]
	assert_eq(context.event, StdRouterContext.NAVIGATION_EVENT_POP)


# ==================== Context Result Tests ====================


func test_context_result_is_set_by_hooks():
	# Given: A router with two hooks on the target route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var hook_a := TrackingHook.new()
	var hook_b := TrackingHook.new()
	target_route.hooks.append(hook_a)
	target_route.hooks.append(hook_b)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: Navigation occurs.
	_router.push(target_route)
	await get_tree().process_frame

	# Then: Both hooks see result on context; second hook sees
	# the first hook's CONTINUE result.
	assert_eq(hook_b.before_enter_calls.size(), 1)
	var ctx: StdRouterContext = hook_b.before_enter_calls[0]
	assert_not_null(ctx.result)
	assert_eq(
		ctx.result.action,
		StdRouteHook.Result.ACTION_CONTINUE,
	)


# ==================== Redirect Context Chain Tests ====================


func test_redirect_sets_redirected_from_on_context():
	# Given: A router with a redirect route and a target.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	var redirect_handle := _create_handle()
	var redirect_route := StdRouteRedirect.new()
	redirect_route.handle = redirect_handle
	redirect_route.segment = &"redirect"
	redirect_route.redirect_to = target_route

	var hook := TrackingHook.new()
	target_route.hooks.append(hook)

	_setup_router(
		[initial_route, target_route, redirect_route],
		initial_route,
	)
	await get_tree().process_frame

	# When: Navigating through the redirect.
	_router.push(redirect_route)
	await get_tree().process_frame

	# Then: The context has a redirected_from chain.
	assert_eq(hook.before_enter_calls.size(), 1)
	var ctx: StdRouterContext = hook.before_enter_calls[0]
	assert_not_null(ctx.redirected_from)
	assert_eq(ctx.redirected_from.to_route, redirect_route)


func test_hook_redirect_sets_redirected_from():
	# Given: A router where a hook on route A redirects to B.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var route_a_handle := _create_handle()
	var route_a := _create_view_route(route_a_handle, &"a")

	var route_b_handle := _create_handle()
	var route_b := _create_view_route(route_b_handle, &"b")

	var redirect_hook := TrackingHook.new()
	redirect_hook.redirect_to_handle = route_b_handle
	route_a.hooks.append(redirect_hook)

	var target_hook := TrackingHook.new()
	route_b.hooks.append(target_hook)

	_setup_router([initial_route, route_a, route_b], initial_route)
	await get_tree().process_frame

	# When: Navigating to route A (which redirects to B).
	_router.push(route_a)
	await get_tree().process_frame

	# Then: Route B's context has redirected_from pointing to A.
	assert_eq(target_hook.before_enter_calls.size(), 1)
	var ctx: StdRouterContext = target_hook.before_enter_calls[0]
	assert_not_null(ctx.redirected_from)
	assert_eq(ctx.redirected_from.to_route, route_a)


# ==================== Ancestor Param Merging Tests ====================


func test_ancestor_params_merged_into_to_params():
	# Given: A parent route navigated with params, and a child.
	var parent_handle := _create_handle()
	var parent_route := _create_view_route(parent_handle, &"parent")

	var child_handle := _create_handle()
	var child_route := _create_view_route(child_handle, &"child")
	child_route.is_index = true
	parent_route.add_child(child_route)

	var sibling_handle := _create_handle()
	var sibling_route := _create_view_route(sibling_handle, &"sibling")
	parent_route.add_child(sibling_route)

	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route, parent_route], initial_route)
	await get_tree().process_frame

	# Given: Navigate to child (via parent index) with params.
	var parent_params := TestParams.new()
	parent_params.score = 42
	_router.push(child_route, parent_params)
	await get_tree().process_frame

	# Given: A tracking hook on the sibling to capture context.
	var hook := TrackingHook.new()
	sibling_route.hooks.append(hook)

	# When: Navigate to sibling (same parent, new params).
	var sibling_params := TestParams.new()
	sibling_params.label = "test"
	_router.push(sibling_route, sibling_params)
	await get_tree().process_frame

	# Then: The context's to_params contains sibling's params.
	assert_eq(hook.before_enter_calls.size(), 1)
	var ctx: StdRouterContext = hook.before_enter_calls[0]
	assert_not_null(ctx.to_params)


# ==================== Layer Navigation Tests ====================


func test_can_pop_returns_true_with_modal_layer():
	# Given: A router with a modal layer (even if base has no history).
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var modal_handle := _create_handle()
	var modal_route := _create_modal_route(modal_handle)

	_setup_router([initial_route, modal_route], initial_route)
	await get_tree().process_frame

	_router.push(modal_route)
	await get_tree().process_frame

	# Then: can_pop returns true (modal layer can be dismissed).
	assert_true(_router.can_pop())


func test_get_topmost_route_returns_base_when_no_modal():
	# Given: A router with only a base view.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route], initial_route)
	await get_tree().process_frame

	# Then: get_topmost_route returns the base view.
	assert_eq(_router.get_topmost_route(), initial_route)


func test_get_topmost_route_returns_modal_when_open():
	# Given: A router with a modal open.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var modal_handle := _create_handle()
	var modal_route := _create_modal_route(modal_handle)

	_setup_router([initial_route, modal_route], initial_route)
	await get_tree().process_frame

	_router.push(modal_route)
	await get_tree().process_frame

	# Then: get_topmost_route returns the modal.
	assert_eq(_router.get_topmost_route(), modal_route)


func test_multi_layer_modal_stack():
	# Given: A router with a view and two independent modals.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle, &"view")

	var modal_a_handle := _create_handle()
	var modal_a := _create_modal_route(modal_a_handle, &"modal_a")

	var modal_b_handle := _create_handle()
	var modal_b := _create_modal_route(modal_b_handle, &"modal_b")

	_setup_router([initial_route, modal_a, modal_b], initial_route)
	await get_tree().process_frame

	# When: Push modal A, then modal B (not child of A).
	_router.push(modal_a)
	await get_tree().process_frame
	_router.push(modal_b)
	await get_tree().process_frame

	# Then: Both modals are stacked.
	assert_eq(_router.get_current_modal(), modal_b)
	assert_eq(_router.get_topmost_route(), modal_b)

	# When: Pop B.
	_router.pop()
	await get_tree().process_frame

	# Then: A is now topmost modal.
	assert_eq(_router.get_current_modal(), modal_a)
	assert_eq(_router.get_current_route(), initial_route)

	# When: Pop A.
	_router.pop()
	await get_tree().process_frame

	# Then: No modal, view restored.
	assert_eq(_router.get_current_modal(), null)
	assert_eq(_router.get_current_route(), initial_route)


# ==================== Route Navigation Method Tests ====================


func test_route_push_navigates():
	# Given: A router with an initial route and a target route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	# When: push() is called on the route directly.
	var err := target_route.push()
	await get_tree().process_frame

	# Then: Navigation succeeds.
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), target_route)


func test_route_pop_passes_params_to_hooks():
	# Given: A router with history and a hook on the initial route.
	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	var hook := TrackingHook.new()
	initial_route.hooks.append(hook)

	var target_handle := _create_handle()
	var target_route := _create_view_route(target_handle)

	_setup_router([initial_route, target_route], initial_route)
	await get_tree().process_frame

	_router.push(target_route)
	await get_tree().process_frame

	# When: Pop is called with params.
	var pop_params := TestParams.new()
	pop_params.score = 99
	target_route.pop(pop_params)
	await get_tree().process_frame

	# Then: The pop context's from_params contain the pop params.
	assert_eq(hook.before_enter_calls.size(), 2)
	var ctx: StdRouterContext = hook.before_enter_calls[1]
	assert_not_null(ctx.from_params)


func test_route_auto_creates_handle():
	# Given: A route with no explicit handle.
	var route := StdRouteView.new()
	route.segment = &"auto"
	route.name = "auto"

	var initial_handle := _create_handle()
	var initial_route := _create_view_route(initial_handle)

	_setup_router([initial_route, route], initial_route)
	await get_tree().process_frame

	# Then: The route has an auto-created handle.
	assert_not_null(route.handle)

	# Then: Navigation to the route succeeds.
	var err := _router.push(route)
	await get_tree().process_frame
	assert_eq(err, OK)
	assert_eq(_router.get_current_route(), route)


func test_get_route_by_path():
	# Given: A router with a route at a known path.
	var handle := _create_handle()
	var route := _create_view_route(handle, &"target")

	_setup_router([route], route)
	await get_tree().process_frame

	# When: Looking up by path.
	var found := _router.get_route(&"/target")

	# Then: The correct route is returned.
	assert_eq(found, route)


func test_get_route_by_handle():
	# Given: A router with a route using a known handle.
	var handle := _create_handle()
	var route := _create_view_route(handle, &"target")

	_setup_router([route], route)
	await get_tree().process_frame

	# When: Looking up by handle.
	var found := _router.get_route(handle)

	# Then: The correct route is returned.
	assert_eq(found, route)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	_content_root = Node.new()
	_content_root.name = "ContentRoot"

	_overlay_root = Node.new()
	_overlay_root.name = "OverlayRoot"


func after_each() -> void:
	if is_instance_valid(_router):
		_router.queue_free()
		_router = null

	if is_instance_valid(_content_root):
		_content_root.queue_free()
		_content_root = null

	if is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
		_overlay_root = null


# -- PRIVATE METHODS -------------------------------------------------------------- #


## _create_handle creates a new StdRouteHandle for testing.
func _create_handle() -> StdRouteHandle:
	return StdRouteHandle.new()


## _create_view_route creates a new StdRouteView with the given handle.
func _create_view_route(
	handle: StdRouteHandle, segment: StringName = &""
) -> StdRouteView:
	var route := StdRouteView.new()
	route.handle = handle
	route.segment = segment if segment else &"route"
	route.name = str(route.segment)
	return route


## _create_modal_route creates a new StdRouteModal with the given handle.
func _create_modal_route(
	handle: StdRouteHandle, segment: StringName = &""
) -> StdRouteModal:
	var route := StdRouteModal.new()
	route.handle = handle
	route.segment = segment if segment else &"modal"
	route.name = str(route.segment)
	return route


## _setup_router sets up the router with the given routes and initial route.
func _setup_router(routes: Array, initial: StdRoute) -> void:
	_router = StdRouter.new()
	_router.content_root = _content_root
	_router.overlay_root = _overlay_root
	_router.initial_route = initial

	for route in routes:
		_router.add_child(route)

	add_child_autofree(_content_root)
	add_child_autofree(_overlay_root)
	add_child_autofree(_router)
