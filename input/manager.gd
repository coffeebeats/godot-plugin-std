##
## std/input/manager.gd
##
## InputManager ...
##

@tool
extends Node
class_name InputManager

# -- DEFINITIONS --------------------------------------------------------------------- #

const _GROUP_INPUT_SCENE := "std/input:manager"

# -- SIGNALS ------------------------------------------------------------------------- #

## joy_device_connected is emitted when a new input device connects to the game.
signal joy_device_connected(device: InputDevice)

## joy_device_disconnected is emitted when an input device disconnects from the game.
signal joy_device_disconnected(device: InputDevice)

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_sets is a list of action sets that this 'InputManager' recognizes.
@export var action_sets: Array[InputActionSet] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

var _connected: Array[InputDevice] = []
var _kbm: InputDevice = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #

func get_kbm_device() -> InputDevice:
    if not _kbm:
        _kbm = _create_kbm_device()

    return _kbm

func get_joy_device(index: int) -> InputDevice:
    return _connected[index]

func get_joy_device_count() -> int:
    return _connected.size()

func remove_joy_device(index: int) -> InputDevice:
    return _connected.pop_at(index)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
    add_to_group(_GROUP_INPUT_SCENE)

func _exit_tree() -> void:
    remove_from_group(_GROUP_INPUT_SCENE)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _create_kbm_device() -> InputDevice:
    return null

func _create_touch_device() -> InputDevice:
    return null

# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _connect_joy_device(device: InputDevice) -> void:
    assert(not device in _connected, "duplicate device")
    _connected.append(device)

    assert(
        device.slot == _connected.find(device),
        "invalid state; mismatching device slot"
    )

    joy_device_connected.emit(device)

func _disconnect_joy_device(slot: int) -> void:
    assert(slot < _connected.size(), "missing device")

    var removed: InputDevice = _connected.pop_at(slot)
    assert(removed, "missing device")

    removed.disconnected.emit()
    joy_device_disconnected.emit(removed)

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = PackedStringArray()

    var seen_actions: Dictionary = {}
    var seen_action_sets: Dictionary = {}

    for i in range(len(action_sets)):
        var warning := "action set '%d'" % i

        if action_sets[i] == null:
            warnings.append("%s: action set is null" % [warning, i])
        
        if action_sets[i].id == "":
            warnings.append("%s: action set is missing its ID" % [warning, i])
            continue
        
        if seen_action_sets.has(action_sets[i].id):
            var other: int = seen_action_sets[action_sets[i].id]
            warnings.append("%s: action set '%d' is duplicated (see index '%d')" % [warning, i, other])
            continue
        
        seen_action_sets[action_sets[i].id] = i

        var actions := action_sets[i].get_actions()
        for j in range(len(actions)):
            if actions[j] == null:
                warnings.append("%s: action '%d' is null" % [warning, j])
                continue
            
            if actions[j].id == "":
                warnings.append("%s: action '%d' is missing its ID" % [warning, j])
                continue

            if actions[j].action_type == InputAction.INPUT_ACTION_TYPE_UNKNOWN:
                warnings.append("%s: action '%d' is missing its action type" % [warning, j])
                continue

            if seen_actions.has(actions[j].id):
                var other: int = seen_actions[actions[j].id]
                warnings.append("%s: action '%d' is duplicated (see action set '%d')" % [warning, j, other])
                continue

            seen_actions[actions[j].id] = i

    return warnings

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
