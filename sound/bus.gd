##
## std/sound/bus.gd
##
## StdAudioBus describes an audio bus.
##

class_name StdAudioBus
extends Resource

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_bus_index returns the index of the audio bus within the audio server.
func get_bus_index() -> int:
	return AudioServer.get_bus_index(_get_bus_name())


## get_bus_name returns the name of the audio bus.
func get_bus_name() -> StringName:
	return _get_bus_name()


## setup performs any necessary work to create the specified audio bus.
func setup() -> void:
	_setup()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_bus_name() -> StringName:
	assert(false, "unimplemented")
	return &""


func _setup() -> void:
	pass
