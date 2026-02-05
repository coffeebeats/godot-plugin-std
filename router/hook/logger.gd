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
					&"route": _get_route_path(context.to_route),
					&"trigger": _get_trigger_name(context.trigger),
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
					&"route": _get_route_path(context.to_route),
					&"trigger": _get_trigger_name(context.trigger),
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
					&"route": _get_route_path(context.to_route),
					&"trigger": _get_trigger_name(context.trigger),
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
					&"route": _get_route_path(context.to_route),
					&"trigger": _get_trigger_name(context.trigger),
				},
			)
		)

	return Result.new()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_route_path(route: Variant) -> String:
	if route == null:
		return "<none>"

	if route.has_method(&"get_full_path"):
		return route.get_full_path()

	return "<unknown>"


func _get_trigger_name(trigger: StdRouteContext.Trigger) -> String:
	match trigger:
		StdRouteContext.Trigger.PUSH:
			return "push"
		StdRouteContext.Trigger.REPLACE:
			return "replace"
		StdRouteContext.Trigger.POP:
			return "pop"
		StdRouteContext.Trigger.REDIRECT:
			return "redirect"
		StdRouteContext.Trigger.INITIAL:
			return "initial"
		_:
			return "unknown"
