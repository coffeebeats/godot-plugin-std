##
## std/input/godot/device_haptics.gd
##
## An implemention of `InputDevice.Haptics` which uses Godot's built-in haptics API.
##

extends InputDevice.Haptics

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## start_vibrate_strong executes a strong vibration effect for the provided duration
## and device
func start_vibrate_strong(device: int, duration: float, strength: float = 1.0) -> bool:
	Input.start_joy_vibration(device, 0, strength, duration)

	return false


## start_vibrate_weak executes a weak vibration effect for the provided duration
## and device.
func start_vibrate_weak(device: int, duration: float, strength: float = 1.0) -> bool:
	Input.start_joy_vibration(device, strength, 0, duration)

	return true


## stop_vibrate stops all ongoing vibration effects *for the device*.
func stop_vibrate(device: int) -> void:
	Input.stop_joy_vibration(device)
