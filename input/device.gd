##
## std/input/device/device.gd
##
## InputDevice ...
##

extends Node
class_name InputDevice

# -- SIGNALS ------------------------------------------------------------------------- #

## connected is emitted when this device connects to the game.
##
## NOTE: It will not be emitted if the device is already connected upon creation.
signal connected

## disconnected is emitted when this device disconnects from the game.
##
## NOTE: It will not be emitted if the device is already disconnected upon creation.
signal disconnected

# -- DEFINITIONS --------------------------------------------------------------------- #

## INPUT_DEVICE_TYPE_UNKNOWN is an unknown input device type.
const INPUT_DEVICE_TYPE_UNKNOWN := Type.INPUT_DEVICE_TYPE_UNKNOWN

## INPUT_DEVICE_TYPE_KBM is a keyboard+mouse device.
##
## NOTE: Only one keyboard+mouse-typed device can be connected at a time.
const INPUT_DEVICE_TYPE_KBM := Type.INPUT_DEVICE_TYPE_KBM

## INPUT_DEVICE_TYPE_JOY is an external controller/joypad device.
const INPUT_DEVICE_TYPE_JOY := Type.INPUT_DEVICE_TYPE_JOY

## Type is an enumeration of categories of input devices.
enum Type {
    INPUT_DEVICE_TYPE_UNKNOWN = 0,
    INPUT_DEVICE_TYPE_KBM = 1,
    INPUT_DEVICE_TYPE_JOY = 2,
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_type is the category of input device; this sets the namespace in which 'slot'
## indexes are compared.
@export var device_type: Type = INPUT_DEVICE_TYPE_UNKNOWN

## profile is a unique identifier for the player profile controlling the input device;
## used to load bindings and settings.
##
## NOTE: For games which do not support multiple profiles in local multiplayer (or are
## single player), this can be left as the default value.
@export var profile: int = 0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active_action_set: StringName = ""
var _active_action_set_layers: Array[StringName] = []

var _active_action_glyphs: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## get_action_display_name returns the display name of the action, suitable for the UI
## to display. This value will be translated based on the user's language settings using
## the id of the action set as the translation context.
func get_action_display_name(action: StringName) -> String:
    assert(action, "invalid input; missing action")
    assert(_active_action_set, "invalid state; missing active action set")
    assert(_is_active_action(action), "invalid input; unknown action")

    return _get_display_name_for_action(action)

## get_action_glyph returns an 'Image' resource containing image data for a glyph icon
## of the specified action's triggering device origin. Note that this value will be
## cached while the device remains connected, assuming an 'Image' was found.
func get_action_glyph(action: StringName) -> Image:
    assert(action, "invalid input; missing action")
    assert(_active_action_set, "invalid state; missing active action set")
    assert(_is_active_action(action), "invalid input; unknown action")

    if action in _active_action_glyphs:
        return _active_action_glyphs[action]

    var img := _get_glyph_for_action(action)
    if not img:
        return null

    _active_action_glyphs[action] = img

    return img

## get_active_action_set returns the name of the currently active action set.
func get_active_action_set() -> StringName:
    return _active_action_set

## load_action_set configures the game to only allow the actions specified in the
## provided 'InputActionSet' to be recognized. Returns whether or not the active action
## set was updated.
func load_action_set(action_set: StringName) -> bool:
    assert(action_set, "invalid input; missing action set")
    assert(not _active_action_set, "invalid state; unload active action set first")

    if _active_action_set == action_set:
        return false

    var bindings: Array[InputEvent] = []

    for action in _get_actions_for_action_set(action_set):
        assert(not InputMap.has_action(action.id), "invalid state; found dangling action")

        if not InputMap.has_action(action.id):
            InputMap.add_action(action.id)

        for event in _get_input_events_for_action(action, profile):
            assert(
                _is_input_event_for_action_type(action, event),
                "invalid config; incorrect action type"
            )

            # Only configure bindings for this device type.
            if not _is_input_event_for_device_type(event):
                continue

            # TODO: This is O(n^2); consider improving for larger action sets.
            for e in bindings:
                assert(not event.is_match(e), "invalid config; found duplicate binding")

            bindings.append(event)

            InputMap.action_add_event(action.id, event)

    _active_action_set = action_set

    return true

## add_action_set_layer configures the game to recognize the actions specified in the
## provided 'InputActionSet' in addition to the currently active actions. Conflicting
## action bindings will be overwritten by later layers, but no actions can be duplicated
## across the base action set and active layers.
func add_action_set_layer(layer: StringName) -> bool:
    assert(layer, "invalid input; missing action set")
    assert(_active_action_set, "invalid state; load action set first")
    assert(_active_action_set_layers != null, "invalid state; missing layers")

    if layer in _active_action_set_layers:
        return false

    # for action in _get_active_actions():
    #     var id := _get_action_id_for_device(action)
    #     assert(
    #         InputMap.has_action(id),
    #         "invalid state; missing registered action"
    #     )

    #     InputMap.erase_action(id)

    # _active_action_set_layers.append(layer)

    # var events: Array[InputEvent] = []

    # for index in range(len(_active_action_set_layers) - 1, -1, -1):
    #     var current := _active_action_set_layers[index]
    #     for action in current.actions:
    #         var id := _get_action_id_for_device(action)
    #         assert(
    #             not InputMap.has_action(id),
    #             "invalid state; found dangling/duplicate action"
    #         )

    #         InputMap.add_action(id)

    #         var layer_events: Array[InputEvent] = []

    #         for event in _get_input_events_for_action(current, action):
    #             event.device = slot

    #             assert(
    #                 not layer_events.any(event.is_match),
    #                 "invalid input; found duplicate binding in layer"
    #             )

    #             layer_events.append(event)

    #             # Skip any bindings present in higher layers.
    #             if events.any(event.is_match):
    #                 continue

    #             events.append(event)

    #             InputMap.action_add_event(id, event)

    # var action_set_events: Array[InputEvent] = []

    # for action in _active_action_set.actions:
    #     var id := _get_action_id_for_device(action)
    #     assert(
    #         not InputMap.has_action(id),
    #         "invalid state; found dangling/duplicate action"
    #     )

    #     InputMap.add_action(id)

    #     for event in _get_input_events_for_action(_active_action_set, action):
    #         event.device = slot

    #         assert(
    #             not action_set_events.any(event.is_match),
    #             "invalid input; found duplicate binding in layer"
    #         )

    #         action_set_events.append(event)

    #         InputMap.action_add_event(id, event)

    return true

## unload_action_set deactivates the active action set, causing the game to stop
## recognizing the actions within it. Returns whether the active action set was updated.
func unload_action_set() -> bool:
    assert(_active_action_set_layers != null, "invalid state; missing layers")

    if not _active_action_set:
        assert(
            _active_action_set_layers.is_empty(),
            "invalid state; found dangling layers",
        )

        return false

    for action in _get_active_actions(): # NOTE: Includes active layer actions.
        assert(InputMap.has_action(action.id), "invalid state; missing action")

        InputMap.erase_action(action.id)

    _active_action_set = ""
    _active_action_set_layers.clear()

    return true

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
    var err := disconnected.connect(_on_self_disconnected)
    assert(err == OK, "failed to connect to signal")

func _exit_tree() -> void:
    assert(disconnected.is_connected(_on_self_disconnected), "missing signal connection")
    disconnected.disconnect(_on_self_disconnected)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _get_input_events_for_action(
    _action: InputAction,
    _profile: int,
) -> Array[InputEvent]:
    return []

func _get_display_name_for_action(action: StringName) -> String:
    assert(action, "invalid input; missing action")

    return tr(action.to_upper(), _active_action_set)

func _get_glyph_for_action(_action: StringName) -> Image:
    return null

func _get_actions_for_action_set(_action_set: StringName) -> Array[InputAction]:
    return []

func _get_actions_for_action_set_layer(_action_set: StringName, _layer: StringName) -> Array[InputAction]:
    return []

# -- PRIVATE METHODS ----------------------------------------------------------------- #

## _get_active_actions returns all actions contained within the active action set and
## any active layers.
func _get_active_actions() -> Array[InputAction]:
    assert(_active_action_set, "invalid state; missing active action set")
    assert(_active_action_set_layers != null, "invalid state; missing layers")

    var actions: Array[InputAction] = []

    for a in _get_actions_for_action_set(_active_action_set):
        actions.append(a)

    for layer in _active_action_set_layers:
        for a in _get_actions_for_action_set_layer(_active_action_set, layer):
            actions.append(a)

    return actions

## _is_active_action returns whether the specified action appears in the set of
## currently active action names.
func _is_active_action(action: StringName) -> bool:
    assert(action, "invalid input; missing action")
    assert(_active_action_set, "invalid state; missing active action set")
    assert(_active_action_set_layers != null, "invalid state; missing layers")

    for a in _get_actions_for_action_set(_active_action_set):
        if action == a.id:
            return true

    for layer in _active_action_set_layers:
        for a in _get_actions_for_action_set_layer(_active_action_set, layer):
            if action == a.id:
                return true

    return false

func _is_input_event_for_action_type(action: InputAction, event: InputEvent) -> bool:
    match action.action_type:
        InputAction.INPUT_ACTION_TYPE_ANALOG_TRIGGER:
            return (
                event is InputEventJoypadMotion and
                (
                    event.axis == JOY_AXIS_TRIGGER_LEFT or
                    event.axis == JOY_AXIS_TRIGGER_RIGHT
                )
            )
        InputAction.INPUT_ACTION_TYPE_BUTTON:
            return (
                event is InputEventJoypadButton or
                event is InputEventKey or
                event is InputEventMouseButton
            )

    return false

func _is_input_event_for_device_type(event: InputEvent) -> bool:
    match device_type:
        INPUT_DEVICE_TYPE_KBM:
            return event is InputEventKey or event is InputEventMouse
        INPUT_DEVICE_TYPE_JOY:
            return (
                event is InputEventJoypadButton or
                event is InputEventJoypadMotion
            )

    return false

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_self_disconnected() -> void:
    # Purge glyph cache upon disconnect in case they were updated by Steam.
    _active_action_glyphs = {}

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
