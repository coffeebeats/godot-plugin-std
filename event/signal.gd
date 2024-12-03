##
## std/event/signal.gd
##
## A shared library for safely managing `Signal` connections.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## connect_safe safely connects the callback to the provided receiver.
static func connect_safe(receiver: Signal, callback: Callable, flags: int = 0) -> Error:
	var err := receiver.connect(callback, flags) as Error
	assert(err == OK, "failed to connect to signal")

	return err


## disconnect_safe safely disconnects the callback from the receiver signal.
static func disconnect_safe(receiver: Signal, callback: Callable) -> void:
	if receiver.is_connected(callback):
		receiver.disconnect(callback)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
