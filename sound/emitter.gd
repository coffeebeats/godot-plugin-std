##
## std/sound/emitter.gd
##
## StdSoundEmitter is a node that manages lifecycle-driven playback of a `StdSoundEvent`
## via the existing `StdSoundEventPlayer` pipeline. It handles autoplay and fade in/out.
##

class_name StdSoundEmitter
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## started is emitted after the sound event begins playback.
signal started(instance: StdSoundInstance)

## stopped is emitted after the sound event playback is stopped.
signal stopped

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## event is the sound event to play.
@export var event: StdSoundEvent = null

## autoplay controls whether the sound begins playing on _ready.
@export var autoplay: bool = false

@export_subgroup("Fade")

## fade_in is the tween curve used when starting playback.
@export var fade_in: StdTweenCurve = null

## fade_out is the tween curve used when stopping playback.
@export var fade_out: StdTweenCurve = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: StdSoundInstance = null
var _player: StdSoundEventPlayer = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_instance returns the active sound instance, or null if not playing.
func get_instance() -> StdSoundInstance:
	return _instance


## is_playing returns whether the emitter has an active sound instance.
func is_playing() -> bool:
	return _instance != null and not _instance.is_done()


## play stops any existing playback, plays the configured event, and emits `started`.
func play() -> StdSoundInstance:
	assert(event is StdSoundEvent, "invalid config; missing event")
	assert(
		_player is StdSoundEventPlayer,
		"invalid state; missing player",
	)

	if is_playing():
		stop()

	_instance = _player.play(event, fade_in)
	if not _instance:
		return null

	_instance.done.connect(_on_instance_done, CONNECT_ONE_SHOT)

	started.emit(_instance)

	return _instance


## stop stops playback with fade_out and emits stopped.
func stop() -> void:
	if not is_playing():
		return

	Signals.disconnect_safe(_instance.done, _on_instance_done)

	_instance.stop(fade_out)
	_instance = null

	stopped.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	stop()


func _ready() -> void:
	if not StdGroup.is_empty(StdSoundEventPlayer.GROUP_SOUND_PLAYER):
		_player = (
			StdGroup
			. get_sole_member(
				StdSoundEventPlayer.GROUP_SOUND_PLAYER,
			)
		)

	if autoplay:
		play()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_instance_done() -> void:
	_instance = null
	stopped.emit()
