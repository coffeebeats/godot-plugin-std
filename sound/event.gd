##
## std/sound/event.gd
##
## StdSoundEvent is a base class for a description of a single sound (e.g. effect or
## music) that can be played by a `StdSoundEventPlayer`. Each event description will be
## instantiated, allowing the same event to be played (and modulated) multiple times in
## parallel.
##

class_name StdSoundEvent
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## stream is the source audio which will be triggered by this event. Each instance of
## this event will use the same audio stream.
@export var stream: AudioStream = null

## volume_db is the target volume level that the audio stream will be played at.
@export_range(-8.0, 6.0) var volume_db: float = 0.0

## bus defines the audio bus through which the audio will be played.
@export var bus: StdAudioBus = null

## params is a list of parameters which can modulate the audio during playback.
##
## NOTE: Each instance of this sound event will *share* the parameters, meaning
## parameters must be unique if sound events should be uniquely controllable.
@export var params: Array[StdSoundParam] = []

## group is an optional sound group to which the sound instance will belong. The group
## allows limiting the number of concurrent audio streams as well as basic group-level
## controls (e.g. mute).
@export var group: StdSoundGroup = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## instantiate creates a new instance of this sound event description. The caller must
## call its `start` method to begin playback.
func instantiate(player: Node) -> StdSoundInstance:
	var instance := StdSoundInstance.new()

	assert(player is Node, "invalid argument; missing player")
	instance.player = player

	_configure(player)
	player.finished.connect(instance.stop, CONNECT_ONE_SHOT)

	assert(stream is AudioStream, "invalid state; missing audio stream")
	instance.stream = stream

	assert(bus is StdAudioBus, "invalid state; missing audio bus")
	instance.bus = bus
	bus.setup()

	assert(not group or group is StdSoundGroup, "invalid config; wrong type")
	instance.group = group

	if group:
		group.reserve(instance)

	for param in _get_params():
		assert(param is StdSoundParam, "invalid config; wrong type")

		var callback := instance._on_param_update.bind(param)
		param.changed.connect(callback)

		(
			instance
			. done
			. connect(
				param.changed.disconnect.bind(callback),
				CONNECT_ONE_SHOT,
			)
		)

		param.apply_to_event_instance(instance)

	return instance


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _configure must be overridden in order to customize how the event's audio player
## should be constructed.
func _configure(_player) -> void:
	assert(false, "unimplemented")


func _get_params() -> Array[StdSoundParam]:
	return params
