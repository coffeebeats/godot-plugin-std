##
## router/hook/action_set.gd
##
## A route lifecycle hook that loads a Steam Input action set when entering a route. If
## the action set is an action set layer (`StdInputActionSetLayer`), then the layer will
## be disconnected on route exit.
##

class_name StdRouteHookActionSet
extends StdRouteHook

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set is the input action set to load when entering this route.
@export var action_set: StdInputActionSet = null

## player_id is the player whose input slot will have the action set
## loaded. Defaults to player 1.
@export var player_id: int = 1

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger: StdLogger = StdLogger.create(&"std/router/hook/action_set")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(action_set, "invalid configuration; missing action set")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _after_enter(_context: StdRouterContext) -> void:
	if action_set == null:
		return

	var slot := StdInputSlot.for_player(player_id)
	if slot == null:
		assert(false, "invalid state; missing input device slot")
		return

	if action_set is StdInputActionSet:
		var enabled := slot.load_action_set(action_set)
		if not enabled:
			(
				_logger
				. warn(
					"Failed to load action set.",
					{&"player": player_id, &"set": action_set.name},
				)
			)
	elif action_set is StdInputActionSetLayer:
		var enabled := slot.enable_action_set_layer(action_set)
		if not enabled:
			(
				_logger
				. warn(
					"Failed to enable action set layer.",
					{&"player": player_id, &"layer": action_set.name},
				)
			)


func _after_exit(_context: StdRouterContext) -> void:
	if action_set == null or not action_set is StdInputActionSetLayer:
		return

	var slot := StdInputSlot.for_player(player_id)
	if slot == null:
		assert(false, "invalid state; missing input device slot")
		return

	if action_set is StdInputActionSetLayer:
		var disabled := slot.disable_action_set_layer(action_set)
		if not disabled:
			(
				_logger
				. warn(
					"Failed to disable action set layer.",
					{&"player": player_id, &"layer": action_set.name},
				)
			)
