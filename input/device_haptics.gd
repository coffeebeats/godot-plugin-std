##
## std/input/device_hatpcis.gd
##
## StdInputDeviceHaptics is an abstract interface for an input device component which
## fetches `StdInputDevice` origin glyphs.
##

class_name StdInputDeviceHaptics
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #


## NoOp is an implementation of `StdInputDeviceHaptics` which does nothing.
class NoOp:
	extends StdInputDeviceHaptics

	func _start_vibrate_strong(
		_device: int, _duration: float, _strength: float
	) -> void:
		pass

	func _start_vibrate_weak(_device: int, _duration: float, _strength: float) -> void:
		pass

	func _stop_vibrate(_device: int) -> void:
		pass


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## start_vibrate_strong initiates an input device vibration for `duration` seconds using
## the device's strong vibration motor, if available.
func start_vibrate_strong(device: int, duration: float, strength: float = 1.0) -> void:
	_start_vibrate_strong(device, duration, strength)


## start_vibrate_weak initiates an input device vibration for `duration` seconds using
## the device's weak vibration motor, if available.
func start_vibrate_weak(device: int, duration: float, strength: float = 1.0) -> void:
	_start_vibrate_weak(device, duration, strength)


## stop_vibrate terminates all ongoing vibration for the input device.
func stop_vibrate(device: int) -> void:
	_stop_vibrate(device)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start_vibrate_strong(_device: int, _duration: float, _strength: float) -> void:
	assert(false, "unimplemented")


func _start_vibrate_weak(_device: int, _duration: float, _strength: float) -> void:
	assert(false, "unimplemented")


func _stop_vibrate(_device: int) -> void:
	assert(false, "unimplemented")
