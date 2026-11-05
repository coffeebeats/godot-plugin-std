##
## std/input/event.gd
##
## StdInputEvent provides utilities for creating and dispatching input events.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'.
##

class_name StdInputEvent
extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

## DEVICE_ID_SYNTHETIC is a sentinel device ID used for synthetic input actions
## triggered by UI elements. This value is chosen to never collide with real joypad
## device IDs (0-15) or Godot's reserved IDs (-1, -2).
const DEVICE_ID_SYNTHETIC := 2 ** 31 - 1

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## refresh_hover pushes a mouse motion at the mouse's position into `viewport`, so that
## a control shown under a resting mouse is hovered without waiting for it to move.
static func refresh_hover(viewport: Viewport) -> void:
	var event := InputEventMouseMotion.new()
	event.position = viewport.get_mouse_position()

	# NOTE: The position is in the viewport's coordinates, so it's pushed as local input
	# or a stretch transform would apply twice.
	viewport.push_input(event, true)


## trigger_action parses a synthetic action press event into the scene tree's input
## system. This allows UI elements like buttons to trigger input actions handled by
## other nodes (e.g. `StdScreenPusher`).
static func trigger_action(
	action: StringName,
	device: int = DEVICE_ID_SYNTHETIC,
	pressed: bool = true,
) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.device = device
	event.pressed = pressed
	Input.parse_input_event(event)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
