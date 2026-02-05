##
## router/hook/logger.gd
##
## A route lifecycle hook that logs navigation events for debugging. Logs are emitted at
## the configured level for each lifecycle event.
##

class_name StdRouteHookLogger
extends StdRouteHook

# -- CONFIGURATION ------------------------------------------------------------------- #

## The log level to use when logging route transitions.
@export var level: StdLogger.Level = StdLogger.LEVEL_INFO

@export_subgroup("Lifecycle")

## log_after_enter controls whether the 'after_enter' lifecycle event is logged.
@export var log_after_enter: bool = true

## log_after_exit controls whether the 'after_exit' lifecycle event is logged.
@export var log_after_exit: bool = true

## log_before_enter controls whether the 'before_enter' lifecycle event is logged.
@export var log_before_enter: bool = true

## log_before_exit controls whether the 'before_exit' lifecycle event is logged.
@export var log_before_exit: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger: StdLogger = StdLogger.create(&"std/router/hook/logger")  # gdlint:ignore=class-definitions-order

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _after_enter(context: StdRouteContext) -> void:
	if log_after_enter:
		(
			_logger
			. log(
				level,
				&"Successfully entered route.",
				{
					&"event": &"after_enter",
					&"route": context.to_route.get_full_path(),
					&"trigger": _get_navigation_event_name(context.event),
				},
			)
		)

	return Result.new()


func _after_exit(context: StdRouteContext) -> void:
	if log_after_exit:
		(
			_logger
			. log(
				level,
				&"Successfully exited route.",
				{
					&"event": &"after_exit",
					&"route": context.to_route.get_full_path(),
					&"trigger": _get_navigation_event_name(context.event),
				},
			)
		)

	return Result.new()


func _before_enter(context: StdRouteContext) -> Result:
	if log_before_enter:
		(
			_logger
			. log(
				level,
				&"Entering route.",
				{
					&"event": &"before_enter",
					&"route": context.to_route.get_full_path(),
					&"trigger": _get_navigation_event_name(context.event),
				},
			)
		)

	return Result.new()


func _before_exit(context: StdRouteContext) -> Result:
	if log_before_exit:
		(
			_logger
			. log(
				level,
				&"About to exit route.",
				{
					&"event": &"before_exit",
					&"route": context.to_route.get_full_path(),
					&"trigger": _get_navigation_event_name(context.event),
				},
			)
		)

	return Result.new()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_navigation_event_name(event: StdRouteContext.NavigationEvent) -> String:
	match event:
		StdRouteContext.NAVIGATION_EVENT_INITIAL:
			return "initial"
		StdRouteContext.NAVIGATION_EVENT_POP:
			return "pop"
		StdRouteContext.NAVIGATION_EVENT_PUSH:
			return "push"
		StdRouteContext.NAVIGATION_EVENT_REDIRECT:
			return "redirect"
		StdRouteContext.NAVIGATION_EVENT_REPLACE:
			return "replace"
		_:
			return "unknown"
