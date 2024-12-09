##
## std/input/godot/device_haptics.gd
##
## An implemention of `StdInputDeviceHaptics` which uses Godot's built-in haptics API.
##

extends StdInputDeviceHaptics

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start_vibrate_strong(device: int, duration: float, strength: float) -> void:
	Input.start_joy_vibration(device, 0, strength, duration)


func _start_vibrate_weak(device: int, duration: float, strength: float) -> void:
	Input.start_joy_vibration(device, strength, 0, duration)


func _stop_vibrate(device: int) -> void:
	Input.stop_joy_vibration(device)
