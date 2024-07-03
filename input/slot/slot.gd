extends Node

signal input_device_changed
signal input_device_connected
signal input_device_disconnected

func get_active_input_device() -> InputDevice:
    return null

func load_action_set(_action_set: InputActionSet) -> bool:
    return false

func unload_action_set(_action_set: InputActionSet) -> bool:
    return false

func add_action_set_layer(_action_set: InputActionSet) -> bool:
    return false

func remove_action_set_layer(_action_set: InputActionSet) -> bool:
    return false

func remove_all_action_set_layers(_action_set: InputActionSet) -> bool:
    return false
