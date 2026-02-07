#gdlint:ignore=max-public-methods,max-file-lines

##
## router/router.gd
##
## The root router node that manages navigation state, route registration, and scene
## lifecycle. Routes are registered as descendant nodes of the router, and navigation
## is performed through StdRoute methods (push/pop/replace).
##
## The router maintains a unified history stack for both views and modals, coordinates
## focus management, and executes guards and hooks during navigation. It supports
## nested routes via StdRouteContainer placeholders in parent scenes.
##

class_name StdRouter
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## navigating is emitted after validation passes but before transitions start.
signal navigating(context: StdRouterContext)

## navigated is emitted after navigation completes successfully.
signal navigated(context: StdRouterContext)

## navigation_failed is emitted when navigation is rejected by guards, hooks,
## or other validation errors.
signal navigation_failed(error: Error)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## State enumerates navigation state machine states.
enum State {  # gdlint:ignore=class-definitions-order
	IDLE,  ## No navigation in progress; ready to accept requests.
	VALIDATING,  ## Running guards and checking preconditions.
	EXITING,  ## Running exit transitions on current routes.
	LOADING,  ## Loading dependencies and instantiating scenes.
	ENTERING,  ## Running enter transitions on new routes.
}


## _NavigationRequest is a queued navigation request to process when idle.
class _NavigationRequest:
	extends RefCounted

	var route: StdRoute
	var params: StdRouteParams
	var pop_params: StdRouteParams
	var trigger: StdRouterContext.NavigationEvent
	var controller: StdRouterController
	var interrupt: bool = false

	## redirected_from is the context from the navigation that triggered
	## this redirect. Used to build the redirect context chain.
	var redirected_from: StdRouterContext = null


# -- CONFIGURATION ------------------------------------------------------------------- #

## content_root is the node where top-level view scenes are instantiated.
@export var content_root: Node

## overlay_root is the node where top-level modal scenes are instantiated.
@export var overlay_root: Node

## initial_route is the route to navigate to on _ready. Must be a
## StdRouteView, not a redirect.
@export var initial_route: StdRoute

@export_group("Global Hooks")

## hooks are applied to all navigations, executed before route-specific hooks.
@export var hooks: Array[StdRouteHook]

@export_group("Transitions")

## default_controller will be used as the default controller to drive route transitions
## from one to the next.
@export var default_controller: StdRouterController = StdRouterControllerSequential.new()

# -- INITIALIZATION ------------------------------------------------------------------ #

## _state is the current navigation state machine state.
var _state: State = State.IDLE

## _base_layer is the base navigation layer for view routes.
var _base_layer: StdRouterLayer = StdRouterLayer.new()

## _modal_layers is the stack of modal navigation layers.
var _modal_layers: Array[StdRouterLayer] = []

## _stage manages all visual state (scenes, overlays, containers, focus).
var _stage: StdRouterStage = null

## _handle_to_route maps route handles to their corresponding route nodes.
var _handle_to_route: Dictionary = {}

## _path_to_route maps full route paths to their corresponding route nodes.
var _path_to_route: Dictionary = {}

## _route_params maps active routes to their navigation params. Used
## to merge ancestor params into navigation contexts.
var _route_params: Dictionary = {}

## _pending_route is the route being transitioned to during navigation. Used to assign
## containers that appear during a transition to the correct route.
var _pending_route: StdRoute = null

## _request_queue holds pending navigation requests to process when idle.
var _request_queue: Array[_NavigationRequest] = []

## _exiting_routes are the routes being exited during the current navigation.
var _exiting_routes: Array[StdRoute] = []

## _entering_routes are the routes being entered during the current navigation.
var _entering_routes: Array[StdRoute] = []

## _loader is the background resource loader for route dependencies.
var _loader: StdRouterLoader = null

## _current_controller is the active transition controller, if any.
var _current_controller: StdRouterController = null

## _pre_nav_layer_count saves modal layer count before a transition starts
## so it can be restored on interrupt cancellation.
var _pre_nav_layer_count: int = 0

## _pre_nav_overlay_snapshot saves overlay state for interrupt rollback.
var _pre_nav_overlay_snapshot: Dictionary = {}

## _pending_load_data stores navigation context during async dependency loading.
var _pending_load_data: Dictionary = {}

## _pending_load_results tracks in-progress load results awaiting completion.
var _pending_load_results: Array[StdRouterLoader.Result] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## push adds a new route onto the history stack. The current route is added to history
## and the target route becomes active. Set interrupt to true to cancel an in-flight
## transition (if the involved routes allow it).
func push(
	route: StdRoute,
	params: StdRouteParams = null,
	controller: StdRouterController = null,
	interrupt: bool = false,
) -> Error:
	assert(route != null, "invalid argument: missing route")

	var request := _NavigationRequest.new()
	request.route = route
	request.params = params
	request.trigger = StdRouterContext.NAVIGATION_EVENT_PUSH
	request.controller = controller if controller else default_controller
	request.interrupt = interrupt

	return _navigate(request)


## replace sets the current route and clears all history. The target route becomes
## active as the new navigation root. Set interrupt to true to cancel an in-flight
## transition (if the involved routes allow it).
func replace(
	route: StdRoute,
	params: StdRouteParams = null,
	controller: StdRouterController = null,
	interrupt: bool = false,
) -> Error:
	assert(route != null, "invalid argument: missing route")

	var request := _NavigationRequest.new()
	request.route = route
	request.params = params
	request.trigger = StdRouterContext.NAVIGATION_EVENT_REPLACE
	request.controller = controller if controller else default_controller
	request.interrupt = interrupt

	return _navigate(request)


## pop returns to the previous route. For modal layers, pops within
## the layer or dismisses it. For the base layer, pops history.
func pop(
	params: StdRouteParams = null,
	controller: StdRouterController = null,
	interrupt: bool = false,
) -> Error:
	var layer := _get_topmost_layer()

	if layer != _base_layer:
		# Modal layer: pop within or dismiss.
		if layer.can_pop():
			var entry := layer.history.peek()
			assert(entry != null, "invalid state: null history")

			var request := _NavigationRequest.new()
			request.route = entry.route
			request.params = entry.params
			request.pop_params = params
			request.trigger = StdRouterContext.NAVIGATION_EVENT_POP
			request.controller = (controller if controller else default_controller)
			request.interrupt = interrupt
			return _navigate(request)

		# No history — dismiss the layer by navigating to the
		# layer beneath's current route.
		return _dismiss_topmost_layer(params, controller, interrupt)

	# Base layer.
	if not layer.can_pop():
		navigation_failed.emit(ERR_DOES_NOT_EXIST)
		return ERR_DOES_NOT_EXIST

	var entry := layer.history.peek()
	assert(entry != null, "invalid state: null history entry")

	var request := _NavigationRequest.new()
	request.route = entry.route
	request.params = entry.params
	request.pop_params = params
	request.trigger = StdRouterContext.NAVIGATION_EVENT_POP
	request.controller = (controller if controller else default_controller)
	request.interrupt = interrupt

	return _navigate(request)


## Returns whether there is a route to pop to.
func can_pop() -> bool:
	if not _modal_layers.is_empty():
		return true
	return _base_layer.can_pop()


## Returns whether a navigation transition is currently in progress.
func is_transitioning() -> bool:
	return _state != State.IDLE


## Returns the currently active base view route.
func get_current_route() -> StdRoute:
	return _base_layer.current_route


## Returns the topmost modal layer's root route, or null.
func get_current_modal() -> StdRouteModal:
	if _modal_layers.is_empty():
		return null
	var layer: StdRouterLayer = _modal_layers.back()
	return layer.root_route


## Returns the absolute topmost route across all layers.
func get_topmost_route() -> StdRoute:
	return _get_topmost_route()


## Returns the full path of the topmost route.
func get_current_path() -> StringName:
	var topmost := _get_topmost_route()
	if topmost == null:
		return &""
	return topmost.get_full_path()


## get_route looks up a route by key. Accepts a StringName/String
## (full path like "/foo/bar") or a StdRouteHandle resource.
func get_route(key: Variant) -> StdRoute:
	if key is StdRouteHandle:
		return _handle_to_route.get(key) as StdRoute
	if key is StringName or key is String:
		return _path_to_route.get(StringName(key)) as StdRoute
	return null


## Serializes the current router state to a JSON string.
func serialize() -> String:
	var data := {}

	if _base_layer.current_route:
		data[&"current"] = {
			&"path": _base_layer.current_route.get_full_path(),
			&"params": _serialize_params(_base_layer.current_params),
		}

	# Serialize modal layer roots.
	var modals: Array[Dictionary] = []
	for layer in _modal_layers:
		if layer.root_route:
			(
				modals
				. append(
					{
						&"path": layer.root_route.get_full_path(),
						&"params": _serialize_params(layer.current_params),
					}
				)
			)

	if not modals.is_empty():
		# Backward compat: single modal uses "modal" key.
		data[&"modal"] = modals[0]
		if modals.size() > 1:
			data[&"modals"] = modals

	# NOTE: History is not serialized; replace clears it.
	return JSON.stringify(data)


## Deserializes router state from a JSON string.
func deserialize(state: String) -> Error:
	var data: Variant = JSON.parse_string(state)
	if data == null or not data is Dictionary:
		navigation_failed.emit(ERR_PARSE_ERROR)
		return ERR_PARSE_ERROR

	var dict := data as Dictionary

	# Restore current route.
	if dict.has(&"current"):
		var current_data: Dictionary = dict[&"current"]
		var route := get_route(current_data[&"path"])
		if route == null:
			navigation_failed.emit(ERR_FILE_NOT_FOUND)
			return ERR_FILE_NOT_FOUND

		var params := _deserialize_params(current_data.get(&"params", {}), route)
		var err := replace(route, params)
		if err != OK:
			return err

	# Restore modals — prefer "modals" array, fall back to "modal".
	var modal_entries: Array = []
	if dict.has(&"modals"):
		modal_entries = dict[&"modals"]
	elif dict.has(&"modal"):
		modal_entries = [dict[&"modal"]]

	for modal_data in modal_entries:
		var route := get_route(modal_data[&"path"])
		if route == null:
			navigation_failed.emit(ERR_FILE_NOT_FOUND)
			return ERR_FILE_NOT_FOUND

		var params := _deserialize_params(modal_data.get(&"params", {}), route)
		var err := push(route, params)
		if err != OK:
			return err

	return OK


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_stage = StdRouterStage.new()
	_stage.content_root = content_root
	_stage.overlay_root = overlay_root
	_stage.overlay_backdrop_clicked.connect(_on_overlay_backdrop_clicked)
	_stage.overlay_cancel_requested.connect(_on_overlay_cancel_requested)

	# Create and configure the background resource loader.
	_loader = StdRouterLoader.new()
	add_child(_loader)

	_register_routes()
	_subscribe_to_container_group()
	_navigate_to_initial_route()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Recursively registers all descendant StdRoute nodes, building the handle->route
## mapping and validating constraints.
func _register_routes() -> void:
	var routes := _find_descendant_routes(self)

	for route in routes:
		_register_route(route)

	_validate_index_routes()
	_build_path_index()


## Registers a single route, injecting the router reference.
func _register_route(route: StdRoute) -> void:
	# Validate 1:1 handle->route mapping.
	if route.handle != null and _handle_to_route.has(route.handle):
		var existing: StdRoute = _handle_to_route[route.handle]
		assert(
			false,
			(
				"invalid state: handle '%s' used by routes: %s, %s"
				% [
					route.segment,
					existing.name,
					route.name,
				]
			)
		)
		return

	if route.handle != null:
		_handle_to_route[route.handle] = route

	route._router = self


## Finds all StdRoute descendants of the given node.
func _find_descendant_routes(node: Node) -> Array[StdRoute]:
	var routes: Array[StdRoute] = []

	for child in node.get_children():
		if child is StdRoute:
			routes.append(child as StdRoute)

		# Recurse into children.
		routes.append_array(_find_descendant_routes(child))

	return routes


## Validates that no parent has multiple children with is_index=true.
func _validate_index_routes() -> void:
	var parents_checked: Dictionary = {}

	for handle in _handle_to_route:
		var route: StdRoute = _handle_to_route[handle]
		var parent := route.get_parent()

		if parent == null or parent in parents_checked:
			continue

		parents_checked[parent] = true

		var index_count := 0
		for child in parent.get_children():
			if child is StdRoute and (child as StdRoute).is_index:
				index_count += 1

		assert(
			index_count <= 1,
			"invalid state: multiple siblings with is_index=true under %s" % parent.name
		)


## _build_path_index populates _path_to_route from registered routes.
func _build_path_index() -> void:
	for handle in _handle_to_route:
		var route: StdRoute = _handle_to_route[handle]
		_path_to_route[route.get_full_path()] = route


## _subscribe_to_container_group subscribes to StdGroup signals for reactive container
## tracking and registers any existing containers.
func _subscribe_to_container_group() -> void:
	var group := StdGroup.with_id(StdRouteContainer.GROUP_ROUTE_CONTAINER)
	group.member_added.connect(_on_container_added)
	group.member_removed.connect(_on_container_removed)

	# Register existing containers.
	for container in StdRouteContainer.all():
		_on_container_added(container)


## Navigates to the initial_route on startup.
func _navigate_to_initial_route() -> void:
	if initial_route == null:
		return

	assert(
		initial_route is StdRouteView,
		"invalid configuration: initial_route must be a StdRouteView"
	)

	var request := _NavigationRequest.new()
	request.route = initial_route
	request.params = null
	request.trigger = StdRouterContext.NAVIGATION_EVENT_INITIAL
	request.controller = default_controller

	_navigate(request)


## Main navigation entry point. Handles queueing, interrupts, and state machine.
## Returns immediately after validation; transitions run asynchronously.
func _navigate(request: _NavigationRequest) -> Error:
	# If transitioning, check interrupt or queue.
	if _state != State.IDLE:
		if request.interrupt and _can_interrupt():
			_cancel_current_navigation()
		else:
			_request_queue.append(request)
			return OK

	# Verify route is registered.
	var route: StdRoute = request.route
	if not _handle_to_route.has(route.handle):
		navigation_failed.emit(ERR_DOES_NOT_EXIST)
		return ERR_DOES_NOT_EXIST

	# Build navigation context.
	var context := _build_context(route, request)

	# Run synchronous validation and start transitions.
	var err := _execute_navigation(route, request, context)
	if err != OK:
		navigation_failed.emit(err)

	return err


## _can_interrupt returns whether the current in-flight transition can be interrupted.
## Both exiting and entering routes must allow interrupts.
func _can_interrupt() -> bool:
	for route in _exiting_routes:
		if (
			route is StdRouteRenderable
			and not (route as StdRouteRenderable).allow_interrupt
		):
			return false

	for route in _entering_routes:
		if (
			route is StdRouteRenderable
			and not (route as StdRouteRenderable).allow_interrupt
		):
			return false

	return true


## _cancel_current_navigation cancels the in-flight navigation, cleaning
## up partially-applied state so a new navigation can start cleanly.
func _cancel_current_navigation() -> void:
	# Cancel pending load results.
	_pending_load_results.clear()
	_pending_load_data = {}

	# Cancel the active controller.
	if _current_controller:
		_current_controller.cancel()
		_current_controller = null

	# Free scenes instantiated for entering routes.
	_stage.cleanup_entering(_entering_routes)

	# Restore layer state from snapshot.
	_restore_layer_snapshot()

	# Reset navigation state.
	_state = State.IDLE
	_pending_route = null
	_exiting_routes = []
	_entering_routes = []


## _build_context builds a StdRouterContext for the navigation, merging
## params from ancestor routes into both from_params and to_params.
func _build_context(route: StdRoute, request: _NavigationRequest) -> StdRouterContext:
	var context := StdRouterContext.new()
	var topmost := _get_topmost_route()
	context.from_route = topmost
	context.to_route = route
	context.router = self
	context.event = request.trigger
	context.redirected_from = request.redirected_from

	# Merge from_route ancestor chain params into from_params.
	if topmost != null:
		for ancestor in _get_ancestor_chain(topmost):
			var p: StdRouteParams = _route_params.get(ancestor)
			if p != null:
				context.merge_into_from_params(p)

	# Merge pop params into from_params so hooks see them.
	if request.pop_params != null:
		context.merge_into_from_params(request.pop_params)

	# Merge to_route ancestor chain params (common ancestors that
	# remain active) into to_params; target's params come last.
	for ancestor in _get_ancestor_chain(route):
		if ancestor == route:
			continue
		var p: StdRouteParams = _route_params.get(ancestor)
		if p != null:
			context.merge_into_to_params(p)

	if request.params != null:
		context.merge_into_to_params(request.params)

	return context


## Executes the navigation state machine. Validation is synchronous; transitions
## are handled asynchronously by the transition controller.
func _execute_navigation(
	route: StdRoute, request: _NavigationRequest, context: StdRouterContext
) -> Error:
	# -- VALIDATING --
	_state = State.VALIDATING

	# Resolve redirects with circular detection.
	var visited: Dictionary = {}
	var resolved: Dictionary = _resolve_route(route, request.params, context, visited)
	if resolved.get(&"error", OK) != OK:
		_state = State.IDLE
		return resolved[&"error"] as Error

	route = resolved[&"route"] as StdRoute
	var params: StdRouteParams = resolved.get(&"params") as StdRouteParams

	# Use the redirect-chained context if redirects were followed.
	context = resolved.get(&"context", context) as StdRouterContext

	# Resolve is_index for routes with children.
	var index_resolved := _resolve_index_route(route)
	if index_resolved == null:
		_state = State.IDLE
		return ERR_INVALID_PARAMETER

	route = index_resolved

	# Update context to reflect the resolved target route.
	context.to_route = route

	# Run guards on all routes in ancestor chain.
	var guard_err := _run_guards(route, context)
	if guard_err != OK:
		_state = State.IDLE
		return guard_err

	# Compute routes to exit using layer-aware logic.
	var is_internal := _is_layer_internal(route)
	var layer := _get_topmost_layer()

	if is_internal:
		if route is StdRouteModal:
			# Layer-internal modal: swap existing modal if any.
			if layer.current_route != null and layer.current_route is StdRouteModal:
				_exiting_routes = ([layer.current_route] as Array[StdRoute])
			else:
				_exiting_routes = [] as Array[StdRoute]
		elif layer.current_route != null and layer.current_route is StdRouteModal:
			# Dismissing a layer-internal modal back to a view.
			_exiting_routes = ([layer.current_route] as Array[StdRoute])
			var view_under := layer.get_view_beneath_modal()
			if view_under != null and route != view_under:
				_exiting_routes.append_array(
					_get_routes_to_exit_from(view_under, route)
				)
		else:
			# View-to-view within layer.
			_exiting_routes = _get_routes_to_exit_from(layer.current_route, route)
	elif route is StdRouteModal:
		# New modal layer — nothing exits.
		_exiting_routes = [] as Array[StdRoute]
	else:
		# Cross-layer view nav — dismiss modal layers + navigate.
		_exiting_routes = _collect_modal_layer_exit_routes()
		_exiting_routes.append_array(
			_get_routes_to_exit_from(_base_layer.current_route, route)
		)

	var exit_hook_result := _run_before_exit_hooks(context)
	if exit_hook_result != null:
		if exit_hook_result.action == StdRouteHook.Result.ACTION_BLOCK:
			_state = State.IDLE
			_exiting_routes = []
			return ERR_UNAUTHORIZED

		if exit_hook_result.action == StdRouteHook.Result.ACTION_REDIRECT:
			_state = State.IDLE
			_exiting_routes = []
			return _redirect(exit_hook_result, request.controller, context)

	# Run before_enter hooks (synchronous, can block/redirect).
	var hook_result := _run_before_enter_hooks(route, context)
	if hook_result != null:
		if hook_result.action == StdRouteHook.Result.ACTION_BLOCK:
			_state = State.IDLE
			_exiting_routes = []
			return ERR_UNAUTHORIZED

		if hook_result.action == StdRouteHook.Result.ACTION_REDIRECT:
			_state = State.IDLE
			_exiting_routes = []
			return _redirect(hook_result, request.controller, context)

	# Verify nested views exist for nested routes.
	var nested_err := _verify_nested_views(route)
	if nested_err != OK:
		_state = State.IDLE
		_exiting_routes = []
		return nested_err

	# -- POINT OF NO RETURN: Navigation accepted --

	# Save current focus before transitioning.
	var topmost_scene := _stage.get_scene(_get_topmost_route())
	_stage.save_focus(topmost_scene, get_viewport())

	# Emit navigating signal now that validation has passed.
	navigating.emit(context)

	# Compute routes to enter using layer-aware logic.
	if is_internal:
		if route is StdRouteModal:
			_entering_routes = [route] as Array[StdRoute]
		elif layer.current_route != null and layer.current_route is StdRouteModal:
			# Dismissing layer-internal modal.
			var view_under := layer.get_view_beneath_modal()
			if route == view_under:
				_entering_routes = [] as Array[StdRoute]
			else:
				_entering_routes = _get_routes_to_enter_from(view_under, route)
		else:
			_entering_routes = _get_routes_to_enter_from(layer.current_route, route)
	elif route is StdRouteModal:
		_entering_routes = [route] as Array[StdRoute]
	else:
		_entering_routes = _get_routes_to_enter_from(_base_layer.current_route, route)

	# Set pending route so containers appearing during transition get assigned correctly.
	_pending_route = route

	# Store navigation data for use after loading completes.
	var navigation_data := {
		&"route": route,
		&"params": params,
		&"request": request,
		&"context": context,
	}

	# Start loading dependencies asynchronously.
	var load_err := _start_loading_dependencies(route, navigation_data)
	if load_err != OK:
		_state = State.IDLE
		_pending_route = null
		_exiting_routes = []
		_entering_routes = []
		return load_err

	return OK  # gdlint:ignore=max-returns


## Called when the transition controller completes. Finalizes state.
func _on_transition_completed(data: Dictionary) -> void:
	_current_controller = null
	_pre_nav_layer_count = 0
	_pre_nav_overlay_snapshot = {}

	var route: StdRoute = data[&"route"]
	var params: StdRouteParams = data[&"params"]
	var request: _NavigationRequest = data[&"request"]
	var context: StdRouterContext = data[&"context"]

	# Run after_exit hooks.
	_run_after_exit_hooks(context)

	# Clean up exiting routes.
	for exiting in _exiting_routes:
		_stage.cleanup_scene(exiting)
		_route_params.erase(exiting)
		if exiting is StdRouteModal:
			_stage.cleanup_overlay(exiting)

	# Remove dismissed modal layers (those whose root_route
	# is in _exiting_routes).
	var i := _modal_layers.size() - 1
	while i >= 0:
		if _modal_layers[i].root_route in _exiting_routes:
			_modal_layers.remove_at(i)
		i -= 1

	# Update layer state based on trigger.
	_update_layer_state(route, params, request)

	# Activate the topmost overlay (or deactivate all).
	var topmost_modal: StdRouteModal = null
	var topmost_route := _get_topmost_route()
	if topmost_route is StdRouteModal:
		topmost_modal = topmost_route as StdRouteModal
	_stage.set_active_overlay(topmost_modal)

	# Run after_enter hooks.
	_run_after_enter_hooks(context)

	# Update focus.
	var topmost := _get_topmost_route()
	if topmost:
		_stage.restore_focus(_stage.get_scene(topmost))

	# -- IDLE --
	_state = State.IDLE
	_pending_route = null
	_exiting_routes = []
	_entering_routes = []

	# Emit navigated signal.
	navigated.emit(context)

	# Process queued requests.
	_process_queue()


## _resolve_route resolves redirects with circular detection. Returns a
## dict with route/params/context/error. Each redirect step creates a
## new context linked via redirected_from.
func _resolve_route(
	route: StdRoute,
	params: StdRouteParams,
	context: StdRouterContext,
	visited: Dictionary,
) -> Dictionary:
	# Check for circular redirect.
	if route in visited:
		push_error("StdRouter: Circular redirect detected at %s" % route.name)
		return {&"error": ERR_CYCLIC_LINK}

	visited[route] = true

	# If not a redirect, return as-is.
	if not route is StdRouteRedirect:
		return {
			&"route": route,
			&"params": params,
			&"context": context,
			&"error": OK,
		}

	var redirect := route as StdRouteRedirect

	# Run guards on redirect route first.
	var guard_err := _run_guards(redirect, context)
	if guard_err != OK:
		return {&"error": guard_err}

	# Resolve target (redirect_to is a direct StdRoute reference).
	var target: StdRoute = redirect.redirect_to
	if target == null:
		push_error("StdRouter: Redirect target not found: %s" % redirect.name)
		return {&"error": ERR_DOES_NOT_EXIST}

	# Chain redirect contexts for hook visibility.
	var redirect_ctx := StdRouterContext.new()
	redirect_ctx.router = context.router
	redirect_ctx.event = StdRouterContext.NAVIGATION_EVENT_REDIRECT
	redirect_ctx.from_route = context.from_route
	redirect_ctx.to_route = target
	redirect_ctx.from_params = context.from_params
	redirect_ctx.to_params = context.to_params
	redirect_ctx.redirected_from = context

	# Preserve or clear params.
	var target_params: StdRouteParams = params if redirect.preserve_params else null

	# Recurse to resolve nested redirects.
	return _resolve_route(target, target_params, redirect_ctx, visited)


## Resolves is_index routes. Returns the index child if route has children.
func _resolve_index_route(route: StdRoute) -> StdRoute:
	# If route has no children, return as-is.
	var has_route_children := false
	for child in route.get_children():
		if child is StdRoute:
			has_route_children = true
			break

	if not has_route_children:
		return route

	# Find the index child.
	for child in route.get_children():
		if child is StdRoute and (child as StdRoute).is_index:
			# Recurse in case index child also has children.
			return _resolve_index_route(child as StdRoute)

	# Route has children but no is_index child.
	push_error("StdRouter: Route '%s' has children but no is_index child" % route.name)
	return null


## Runs guards on all routes in the ancestor chain.
func _run_guards(route: StdRoute, context: StdRouterContext) -> Error:
	var ancestor_chain := _get_ancestor_chain(route)

	for ancestor in ancestor_chain:
		for guard in ancestor.guards:
			if not guard.is_allowed(context):
				return ERR_UNAUTHORIZED

	return OK


## Returns the ancestor chain from root to leaf (inclusive).
func _get_ancestor_chain(route: StdRoute) -> Array[StdRoute]:
	var chain: Array[StdRoute] = []
	var current: Node = route

	while current:
		if current is StdRoute:
			chain.push_front(current as StdRoute)

		current = current.get_parent()
		if current == self:
			break

	return chain


## _run_before_enter_hooks runs before_enter hooks on global hooks and
## route hooks. Each result is stored on context.result so subsequent
## hooks can inspect the chain.
func _run_before_enter_hooks(
	route: StdRoute, context: StdRouterContext
) -> StdRouteHook.Result:
	# Global hooks first.
	for hook in hooks:
		var result := hook.before_enter(context)
		context.result = result
		if result.action != StdRouteHook.Result.ACTION_CONTINUE:
			return result

	# Route hooks in ancestor chain.
	var ancestor_chain := _get_ancestor_chain(route)
	for ancestor in ancestor_chain:
		for hook in ancestor.hooks:
			var result := hook.before_enter(context)
			context.result = result
			if result.action != StdRouteHook.Result.ACTION_CONTINUE:
				return result

	return null


## _run_before_exit_hooks runs before_exit hooks on current routes.
## Each result is stored on context.result for chain visibility.
func _run_before_exit_hooks(
	context: StdRouterContext,
) -> StdRouteHook.Result:
	for route in _exiting_routes:
		for hook in route.hooks:
			var result := hook.before_exit(context)
			context.result = result
			if result.action != StdRouteHook.Result.ACTION_CONTINUE:
				return result

	# Global hooks.
	for hook in hooks:
		var result := hook.before_exit(context)
		context.result = result
		if result.action != StdRouteHook.Result.ACTION_CONTINUE:
			return result

	return null


## Runs after_enter hooks.
func _run_after_enter_hooks(context: StdRouterContext) -> void:
	# Route hooks in ancestor chain.
	var topmost := _get_topmost_route()
	if topmost != null:
		var ancestor_chain := _get_ancestor_chain(topmost)
		for ancestor in ancestor_chain:
			for hook in ancestor.hooks:
				hook.after_enter(context)

	# Global hooks.
	for hook in hooks:
		hook.after_enter(context)


## Runs after_exit hooks.
func _run_after_exit_hooks(context: StdRouterContext) -> void:
	for route in _exiting_routes:
		for hook in route.hooks:
			hook.after_exit(context)

	# Global hooks.
	for hook in hooks:
		hook.after_exit(context)


## _verify_nested_views verifies that required StdRouteContainer nodes exist for nested
## routes. Delegates to stage with the ancestor chain computed here.
func _verify_nested_views(route: StdRoute) -> Error:
	return _stage.verify_nested(_get_ancestor_chain(route))


## _get_topmost_layer returns the topmost navigation layer.
func _get_topmost_layer() -> StdRouterLayer:
	if not _modal_layers.is_empty():
		return _modal_layers.back() as StdRouterLayer
	return _base_layer


## _get_topmost_route returns the topmost route across all layers.
func _get_topmost_route() -> StdRoute:
	var layer := _get_topmost_layer()
	return layer.current_route


## _is_layer_internal returns whether a target route belongs to the
## same navigation layer as the topmost layer's current route. A
## route is layer-internal if it shares a common root ancestor
## (first element of the ancestor chain) with the current route.
func _is_layer_internal(target: StdRoute) -> bool:
	var layer := _get_topmost_layer()
	if layer.current_route == null:
		return layer == _base_layer
	var cur := _get_ancestor_chain(layer.current_route)
	var tgt := _get_ancestor_chain(target)
	if cur.is_empty() or tgt.is_empty():
		return false
	return cur[0] == tgt[0]


## _collect_modal_layer_exit_routes gathers all routes from all
## modal layers in leaf-to-root order for cross-layer dismissal.
func _collect_modal_layer_exit_routes() -> Array[StdRoute]:
	var routes: Array[StdRoute] = []
	for i in range(_modal_layers.size() - 1, -1, -1):
		var layer: StdRouterLayer = _modal_layers[i]
		var layer_routes := layer.collect_routes()
		for route in layer_routes:
			if route not in routes:
				routes.append(route)
	return routes


## _dismiss_topmost_layer creates a navigation request to dismiss
## the topmost modal layer by navigating to the layer beneath.
func _dismiss_topmost_layer(
	pop_params: StdRouteParams,
	controller: StdRouterController,
	interrupt: bool,
) -> Error:
	# Find the route to navigate to (layer beneath's current).
	var beneath: StdRouterLayer
	if _modal_layers.size() > 1:
		beneath = _modal_layers[_modal_layers.size() - 2]
	else:
		beneath = _base_layer

	var target_route := beneath.current_route
	if target_route == null:
		navigation_failed.emit(ERR_DOES_NOT_EXIST)
		return ERR_DOES_NOT_EXIST

	var request := _NavigationRequest.new()
	request.route = target_route
	request.params = beneath.current_params
	request.pop_params = pop_params
	request.trigger = StdRouterContext.NAVIGATION_EVENT_POP
	request.controller = (controller if controller else default_controller)
	request.interrupt = interrupt

	return _navigate(request)


## Returns routes to exit from a given source (leaf to common
## ancestor, exclusive).
func _get_routes_to_exit_from(
	from_route: StdRoute, target: StdRoute
) -> Array[StdRoute]:
	if from_route == null:
		return []

	var current_chain := _get_ancestor_chain(from_route)
	var target_chain := _get_ancestor_chain(target)

	var common_depth := 0
	for i in range(mini(current_chain.size(), target_chain.size())):
		if current_chain[i] != target_chain[i]:
			break
		common_depth = i + 1

	var to_exit: Array[StdRoute] = []
	for i in range(current_chain.size() - 1, common_depth - 1, -1):
		to_exit.append(current_chain[i])

	return to_exit


## Returns routes to enter towards a target from a given source
## (common ancestor exclusive to leaf).
func _get_routes_to_enter_from(
	from_route: StdRoute, target: StdRoute
) -> Array[StdRoute]:
	var current_chain: Array[StdRoute] = []
	if from_route != null:
		current_chain = _get_ancestor_chain(from_route)

	var target_chain := _get_ancestor_chain(target)

	var common_depth := 0
	for i in range(mini(current_chain.size(), target_chain.size())):
		if current_chain[i] != target_chain[i]:
			break
		common_depth = i + 1

	var to_enter: Array[StdRoute] = []
	for i in range(common_depth, target_chain.size()):
		to_enter.append(target_chain[i])

	return to_enter


## _start_loading_dependencies begins loading dependencies asynchronously and transitions
## the navigation state machine based on the route's dependency_wait_mode.
func _start_loading_dependencies(route: StdRoute, data: Dictionary) -> Error:
	var paths := _collect_dependencies(route)

	match route.dependency_wait_mode:
		StdRoute.DEPENDENCY_WAIT_MODE_ALLOW:
			# Queue loads but proceed immediately without waiting.
			for path in paths:
				_loader.load(path)
			_on_dependencies_loaded(data)
			return OK

		StdRoute.DEPENDENCY_WAIT_MODE_BLOCK:
			if paths.is_empty():
				_on_dependencies_loaded(data)
				return OK

			# Transition to LOADING state and wait for all loads to complete.
			_state = State.LOADING
			_pending_load_data = data
			_pending_load_results.clear()

			for path in paths:
				var result := _loader.load(path)
				if result.is_done():
					# Already cached - no need to wait.
					continue
				_pending_load_results.append(result)
				result.done.connect(_on_load_result_done.bind(result), CONNECT_ONE_SHOT)

			# If all results were cached, proceed immediately.
			if _pending_load_results.is_empty():
				_on_dependencies_loaded(data)

			return OK

		StdRoute.DEPENDENCY_WAIT_MODE_REJECT:
			# Reject navigation if any dependency is not already cached.
			for path in paths:
				if not ResourceLoader.has_cached(path):
					return ERR_FILE_NOT_FOUND
			_on_dependencies_loaded(data)
			return OK

	return OK


## _on_load_result_done is called when a single load result completes. Checks if all
## pending loads are done and proceeds with navigation if so.
func _on_load_result_done(result: StdRouterLoader.Result) -> void:
	# Ignore stale callbacks from cancelled navigations.
	if result not in _pending_load_results:
		return

	_pending_load_results.erase(result)

	# Check if all pending loads are complete.
	if _pending_load_results.is_empty():
		var data := _pending_load_data
		_pending_load_data = {}
		_on_dependencies_loaded(data)


## _on_dependencies_loaded dispatches to the appropriate transition
## based on route type and layer context.
func _on_dependencies_loaded(data: Dictionary) -> void:
	# Save layer state snapshot for interrupt rollback.
	_save_layer_snapshot()

	var route: StdRoute = data[&"route"]
	var layer := _get_topmost_layer()
	var is_internal := _is_layer_internal(route)

	if route is StdRouteModal:
		_start_modal_transition(route as StdRouteModal, data, layer, is_internal)
	elif layer.current_route != null and layer.current_route is StdRouteModal:
		# Dismissing a modal (layer-internal or cross-layer).
		_start_modal_dismissal(route, data, layer)
	elif not is_internal and not _modal_layers.is_empty():
		# Cross-layer view nav — dismiss overlays + view transit.
		_stage.cleanup_all_overlays()
		_start_view_transition(route, data)
	else:
		_start_view_transition(route, data)


## _start_modal_transition handles pushing a modal route.
func _start_modal_transition(
	modal: StdRouteModal,
	data: Dictionary,
	layer: StdRouterLayer,
	is_internal: bool,
) -> void:
	var instance: Node = _stage.instantiate(modal)
	var overlay := _stage.create_overlay(modal)
	_stage.set_active_overlay(modal)

	if instance != null:
		overlay.ready.connect(
			func() -> void: overlay.add_child(instance),
			CONNECT_ONE_SHOT,
		)

	# Get old overlay if swapping modals within a layer.
	var old_overlay: Node = null
	if layer.current_route != null and layer.current_route is StdRouteModal:
		var old_modal := layer.current_route as StdRouteModal
		old_overlay = _stage.get_overlay(old_modal)
		if old_overlay:
			_stage.disconnect_overlay(old_modal)

	# Create new modal layer if cross-layer.
	if not is_internal:
		var new_layer := StdRouterLayer.new()
		new_layer.root_route = modal
		_modal_layers.append(new_layer)

	var container := _stage.get_container(modal, _get_ancestor_chain(modal))
	var transition_exit: StdRouteTransition = null
	if layer.current_route != null and layer.current_route is StdRouteRenderable:
		transition_exit = (layer.current_route as StdRouteRenderable).transition_exit
	var transition_enter := _get_enter_transition(modal)

	_start_controller(
		data,
		container,
		old_overlay,
		overlay,
		transition_exit,
		transition_enter,
	)


## _start_modal_dismissal handles dismissing a modal to a view.
func _start_modal_dismissal(
	route: StdRoute,
	data: Dictionary,
	layer: StdRouterLayer,
) -> void:
	var current_modal := layer.current_route as StdRouteModal
	var view_under := layer.get_view_beneath_modal()
	var same_view := route == view_under

	if same_view:
		# Dismiss modal only; view stays in place.
		var old_overlay: Node = _stage.get_overlay(current_modal)
		if old_overlay:
			_stage.disconnect_overlay(current_modal)

		var container := (
			_stage
			. get_container(
				current_modal,
				_get_ancestor_chain(current_modal),
			)
		)
		var transition_exit: StdRouteTransition = current_modal.transition_exit

		_start_controller(
			data,
			container,
			old_overlay,
			null,
			transition_exit,
			null,
		)
	else:
		# Dismiss modal immediately, then transition views.
		_stage.cleanup_overlay(current_modal)
		_start_view_transition(route, data)


## _start_view_transition handles view-to-view navigation.
func _start_view_transition(route: StdRoute, data: Dictionary) -> void:
	var new_scene: Node = _stage.instantiate(route)
	var layer := _get_topmost_layer()
	var old_scene: Node = null
	if layer.current_route != null:
		old_scene = _stage.get_scene(layer.current_route)
	var container: Node = _stage.get_container(route, _get_ancestor_chain(route))

	var transition_exit := _get_exit_transition_for(layer.current_route)
	var transition_enter := _get_enter_transition(route)

	_start_controller(
		data,
		container,
		old_scene,
		new_scene,
		transition_exit,
		transition_enter,
	)


## _start_controller wires up and starts a transition controller with the given
## scenes, container, and transitions.
func _start_controller(
	data: Dictionary,
	container: Node,
	old_scene: Node,
	new_scene: Node,
	transition_exit: StdRouteTransition,
	transition_enter: StdRouteTransition,
) -> void:
	var request: _NavigationRequest = data[&"request"]
	var controller := request.controller
	if controller == null:
		controller = StdRouterControllerSequential.new()

	_state = State.EXITING
	_current_controller = controller

	controller.completed.connect(_on_transition_completed.bind(data), CONNECT_ONE_SHOT)
	(
		controller
		. start(
			container,
			old_scene,
			new_scene,
			transition_exit,
			transition_enter,
		)
	)


## _collect_dependencies returns all resource paths that need to be
## loaded for the given route, including the scene_path if renderable
## and child route dependencies based on child_dependency_load_mode.
func _collect_dependencies(route: StdRoute) -> Array[String]:
	var paths: Array[String] = []

	_append_route_deps(route, paths)

	# Include child dependencies based on mode.
	if route is StdRouteRenderable:
		var mode := (route as StdRouteRenderable).child_dependency_load_mode
		if mode != StdRouteRenderable.CHILD_DEPENDENCY_LOAD_OFF:
			var recursive := mode == StdRouteRenderable.CHILD_DEPENDENCY_LOAD_RECURSIVE
			_append_child_deps(route, paths, recursive)

	return paths


## _append_route_deps appends a single route's scene and explicit
## dependencies to the paths array.
func _append_route_deps(route: StdRoute, paths: Array[String]) -> void:
	if route is StdRouteRenderable:
		var renderable := route as StdRouteRenderable
		if (
			renderable.scene_path
			and not renderable.scene_path.is_empty()
			and renderable.scene_path not in paths
		):
			paths.append(renderable.scene_path)

	for deps in route.dependencies:
		for path in deps.resources:
			if path not in paths:
				paths.append(path)


## _append_child_deps appends child route dependencies. When recursive
## is true, descends into all descendant routes.
func _append_child_deps(node: Node, paths: Array[String], recursive: bool) -> void:
	for child in node.get_children():
		if child is StdRoute:
			_append_route_deps(child as StdRoute, paths)
			if recursive:
				_append_child_deps(child, paths, true)


## Gets the exit transition for a given route.
func _get_exit_transition_for(route: StdRoute) -> StdRouteTransition:
	if route == null:
		return null
	if not route is StdRouteRenderable:
		return null
	return (route as StdRouteRenderable).transition_exit


## Gets the enter transition from a route.
func _get_enter_transition(route: StdRoute) -> StdRouteTransition:
	if not route is StdRouteRenderable:
		return null
	return (route as StdRouteRenderable).transition_enter


## _update_layer_state updates history and current route on the
## appropriate layer after a successful navigation.
func _update_layer_state(
	route: StdRoute,
	params: StdRouteParams,
	request: _NavigationRequest,
) -> void:
	# Track per-route params for ancestor chain merging.
	if params != null:
		_route_params[route] = params
	else:
		_route_params.erase(route)

	match request.trigger:
		StdRouterContext.NAVIGATION_EVENT_PUSH:
			_get_topmost_layer().push_state(route, params)

		StdRouterContext.NAVIGATION_EVENT_REPLACE:
			for ml in _modal_layers:
				ml.clear()
			_modal_layers.clear()
			_base_layer.clear()
			_base_layer.set_current(route, params)

		StdRouterContext.NAVIGATION_EVENT_POP:
			_get_topmost_layer().pop_state(route, params)

		StdRouterContext.NAVIGATION_EVENT_REDIRECT:
			_get_topmost_layer().set_current(route, params)

		StdRouterContext.NAVIGATION_EVENT_INITIAL:
			_base_layer.set_current(route, params)


## _save_layer_snapshot records layer state for interrupt rollback.
func _save_layer_snapshot() -> void:
	_pre_nav_layer_count = _modal_layers.size()
	_pre_nav_overlay_snapshot = _stage.snapshot_overlays()


## _restore_layer_snapshot rolls back layer state on cancel.
func _restore_layer_snapshot() -> void:
	if _pre_nav_layer_count == 0 and _pre_nav_overlay_snapshot.is_empty():
		return

	# Remove layers added during this navigation.
	while _modal_layers.size() > _pre_nav_layer_count:
		_modal_layers.pop_back()

	# Restore overlay state.
	_stage.restore_overlay_snapshot(_pre_nav_overlay_snapshot)

	# Reactivate the topmost overlay after restore.
	var topmost_modal: StdRouteModal = null
	var topmost_route := _get_topmost_route()
	if topmost_route is StdRouteModal:
		topmost_modal = topmost_route as StdRouteModal
	_stage.set_active_overlay(topmost_modal)

	_pre_nav_layer_count = 0
	_pre_nav_overlay_snapshot = {}


## _redirect creates a redirect navigation request from a hook result,
## threading the current context for redirect chain visibility.
func _redirect(
	result: StdRouteHook.Result,
	controller: StdRouterController,
	context: StdRouterContext,
) -> Error:
	var route: StdRoute = _handle_to_route.get(result.redirect_to)
	if route == null:
		push_error("StdRouter: redirect handle not registered")
		return ERR_DOES_NOT_EXIST

	var request := _NavigationRequest.new()
	request.route = route
	request.params = result.redirect_params
	request.trigger = StdRouterContext.NAVIGATION_EVENT_REDIRECT
	request.controller = controller
	request.redirected_from = context
	return _navigate(request)


## _process_queue processes queued navigation requests.
func _process_queue() -> void:
	if _request_queue.is_empty():
		return

	var next := _request_queue.pop_front() as _NavigationRequest
	_navigate(next)


## _serialize_params serializes route params to a dictionary by
## storing them into a temporary Config via StdConfigItem.store().
func _serialize_params(params: StdRouteParams) -> Dictionary:
	if params == null:
		return {}

	var config := Config.new()
	params.store(config)

	var category := params.get_category()
	if not config.has_category(category):
		return {}

	return config._data[category].duplicate(true)


## _deserialize_params deserializes route params from a dictionary
## by populating a Config and loading via StdConfigItem.load().
## Uses the route's params schema to create a mutable clone.
func _deserialize_params(data: Dictionary, route: StdRoute) -> StdRouteParams:
	if data.is_empty():
		return null

	if route.params == null:
		return null

	var params := route.params.clone() as StdRouteParams

	var config := Config.new()
	var category := params.get_category()
	config._data[category] = data.duplicate(true)

	params.load(config)
	return params


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_overlay_backdrop_clicked handles backdrop clicks on the modal overlay and pops
## the current modal.
func _on_overlay_backdrop_clicked(_event: InputEventMouseButton) -> void:
	pop()


## _on_overlay_cancel_requested handles cancel input on the modal overlay and pops
## the current modal.
func _on_overlay_cancel_requested() -> void:
	pop()


## _on_container_added handles a container being added to the StdGroup. Assigns it to
## the pending route if navigating, otherwise assigns to null (root container).
func _on_container_added(member: Variant) -> void:
	var container := member as StdRouteContainer
	if container == null:
		return

	# Determine which route to assign this container to.
	var route: StdRoute = null
	if _state != State.IDLE and _pending_route != null:
		route = _pending_route

	_stage.register_container(container, route)


## _on_container_removed handles a container being removed from the StdGroup.
func _on_container_removed(member: Variant) -> void:
	var container := member as StdRouteContainer
	if container == null:
		return

	_stage.unregister_container(container)
