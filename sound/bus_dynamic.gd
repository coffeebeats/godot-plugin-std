##
## std/sound/bus.gd
##
## StdAudioBus describes a dynamic audio bus which can be created on-the-fly for game-
## specific purposes.
##

class_name StdAudioBusDynamic
extends StdAudioBus

# -- CONFIGURATION ------------------------------------------------------------------- #

## send_bus is the audio bus to which this dynamic bus will be routed to.
@export var send_bus: StdAudioBus = null:
	set = _set_send_bus

## effects is a list of audio effects that will be applied to the created audio bus.
@export var effects: Array[AudioEffect] = []:
	set = _set_bus_effects

# -- INITIALIZATION ------------------------------------------------------------------ #

## NOTE: The bus name needs to be stored because this object won't be valid during the
## "predelete" phase; see https://github.com/godotengine/godot/issues/6784.
var _bus_name: StringName = &""

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			if not _bus_name:
				return  # Never used, so no need to delete.

			# NOTE: Can't use `_get_bus_name()`; see note on `_bus_name`.
			var index := AudioServer.get_bus_index(_bus_name)
			if index == -1:
				return

			AudioServer.remove_bus(index)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_bus_name() -> StringName:
	return str(get_instance_id())


func _setup() -> void:
	_bus_name = _get_bus_name()

	assert(
		AudioServer.get_bus_index(_bus_name) == -1,
		"invalid state; found existing bus",
	)

	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, _bus_name)

	# Trigger property setters.
	send_bus = send_bus
	effects = effects


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


func _set_bus_effects(value: Array[AudioEffect]) -> void:
	assert(value is Array[AudioEffect], "invalid config; wrong type")
	effects = value

	var bus_index := AudioServer.get_bus_index(_get_bus_name())
	assert(bus_index > -1, "invalid state; missing bus index")

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

	changed.emit()


func _set_send_bus(value: StdAudioBus) -> void:
	assert(value is StdAudioBus, "invalid config; wrong type")
	send_bus = value

	var bus_index := AudioServer.get_bus_index(_get_bus_name())
	assert(bus_index > -1, "invalid state; missing bus index")

	var send_bus_name := value._get_bus_name()
	assert(AudioServer.get_bus_index(send_bus_name) > -1, "invalid state; missing bus")
	AudioServer.set_bus_send(bus_index, send_bus_name)

	changed.emit()
