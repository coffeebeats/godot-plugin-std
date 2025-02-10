##
## std/sound/bus.gd
##
## StdAudioBus describes a dynamic audio bus which can be created on-the-fly for game-
## specific purposes.
##
## NOTE: This class is *not* meant to be modified during audio playback. Modulations
## of an audio bus should be driven through an `StdSoundParam` rather than on the audio
## bus resource directly. As such, changes to exported properties will not be handled
## for existing audio buses.
##

class_name StdAudioBusDynamic
extends StdAudioBus

# -- CONFIGURATION ------------------------------------------------------------------- #

## send_bus is the audio bus to which this dynamic bus will be routed to.
@export var send_bus: StdAudioBus = null

## effects is a list of audio effects that will be applied to the created audio bus.
@export var effects: Array[AudioEffect] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

## NOTE: The bus name needs to be stored because this object won't be valid during the
## "predelete" phase; see https://github.com/godotengine/godot/issues/6784.
var _bus_name: StringName = &""
var _is_setup_complete: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			if not _is_setup_complete:
				return  # Never used, so no need to delete.

			# NOTE: Can't use `_get_bus_name()`; see note on `_bus_name`.
			var index := AudioServer.get_bus_index(_bus_name)
			if index == -1:
				return

			AudioServer.remove_bus(index)

			_logger.debug("Removed audio bus.", {&"name": _bus_name, &"index": index})


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_bus_name() -> StringName:
	return str(get_instance_id())


func _setup() -> void:
	assert(send_bus is StdAudioBus, "invalid config; missing output audio bus")
	assert(effects is Array[AudioEffect], "invalid config; wrong type")

	if _is_setup_complete:
		assert(
			AudioServer.get_bus_index(_get_bus_name()) > -1,
			"invalid state; missing bus",
		)

		return  # Already set up; no need to do anything.

	var bus_name := _get_bus_name()

	assert(
		AudioServer.get_bus_index(bus_name) == -1,
		"invalid state; found existing bus",
	)

	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)

	_update_audio_bus_send_bus(index)
	_update_audio_bus_effects(index)

	_logger.debug("Added audio bus.", {&"name": bus_name, &"index": index})

	_bus_name = bus_name
	_is_setup_complete = true


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_audio_bus_send_bus(bus_index: int) -> void:
	var send_bus_name := send_bus._get_bus_name()
	assert(AudioServer.get_bus_index(send_bus_name) > -1, "invalid state; missing bus")
	AudioServer.set_bus_send(bus_index, send_bus_name)


func _update_audio_bus_effects(bus_index: int) -> void:
	# Clear any existing bus effects. There shouldn't be any because effects should
	# not be changed at runtime (i.e. this runs just once).
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		assert(false, "invalid state; unexpected bus effect")
		AudioServer.remove_bus_effect(bus_index, effect_index)

	for effect in effects:
		if not effect is AudioEffect:
			assert(false, "invalid config; missing effect")
			continue

		AudioServer.add_bus_effect(bus_index, effect)
