##
## std/sound/music.gd
##
## StdMusicPlayer manages a single music track with crossfade support. Playing a new
## event automatically stops the previous one; playing the same event is a no-op.
##

class_name StdMusicPlayer
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## started is emitted after a new music track begins playback.
signal started(instance: StdSoundInstance)

## stopped is emitted after music playback stops.
signal stopped

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## fade_in is the default tween curve for starting music playback.
@export var fade_in: StdTweenCurve = null

## fade_out is the default tween curve for stopping music playback.
@export var fade_out: StdTweenCurve = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active_event: StdSoundEvent = null
var _active_instance: StdSoundInstance = null
var _player: StdSoundEventPlayer = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_instance returns the active sound instance, or null if not playing.
func get_instance() -> StdSoundInstance:
	return _active_instance


## is_playing returns whether music is currently playing.
func is_playing() -> bool:
	return _active_instance != null and not _active_instance.is_done()


## play starts the given music event. If the same event is already playing, this is a
## no-op. If a different event is playing, it's stopped first. The fade curves can be
## overridden via the optional parameters.
func play(
	event: StdSoundEvent,
	in_curve: StdTweenCurve = null,
	out_curve: StdTweenCurve = null,
) -> void:
	assert(event is StdSoundEvent, "invalid argument; missing event")

	if _active_event == event and is_playing():
		return

	if is_playing():
		_stop(out_curve)

	_active_event = event

	assert(_player is StdSoundEventPlayer, "invalid state; missing player")

	var curve := in_curve if in_curve else fade_in
	_active_instance = _player.play(event, curve)

	if not _active_instance:
		_active_event = null
		return

	_active_instance.done.connect(_on_instance_done, CONNECT_ONE_SHOT)

	started.emit(_active_instance)


## stop stops the current music with an optional fade curve override.
func stop(out_curve: StdTweenCurve = null) -> void:
	if not is_playing():
		return

	_stop(out_curve)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if is_playing():
		_stop(null)


func _ready() -> void:
	if not StdGroup.is_empty(StdSoundEventPlayer.GROUP_SOUND_PLAYER):
		_player = StdGroup.get_sole_member(StdSoundEventPlayer.GROUP_SOUND_PLAYER)


# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _stop(out_curve: StdTweenCurve) -> void:
	if not is_playing():
		return

	Signals.disconnect_safe(_active_instance.done, _on_instance_done)

	var curve := out_curve if out_curve else fade_out
	_active_event = null
	_active_instance = null
	_active_instance.stop(curve)

	stopped.emit()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_instance_done() -> void:
	_active_event = null
	_active_instance = null
	stopped.emit()
