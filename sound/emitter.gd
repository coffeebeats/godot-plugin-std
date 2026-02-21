##
## std/sound/emitter.gd
##
## StdSoundEmitter is a node that manages lifecycle-driven playback of a `StdSoundEvent`
## via the existing `StdSoundEventPlayer` pipeline. It handles autoplay, fade in/out,
## and applying audio effects when the screen is covered or uncovered.
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

@export_subgroup("Screen")

## covered_params is a list of audio effect parameters applied when the screen
## containing this emitter is covered. These are managed by the emitter and should not
## be placed in the event's `params` array.
@export var covered_params: Array[StdSoundParamAudioEffect] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/sound/emitter")  # gdlint:ignore=class-definitions-order,max-line-length

var _instance: StdSoundInstance = null
var _is_covered: bool = false
var _player: StdSoundEventPlayer = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_instance returns the active sound instance, or null if not playing.
func get_instance() -> StdSoundInstance:
	return _instance


## is_playing returns whether the emitter has an active sound instance.
func is_playing() -> bool:
	return _instance != null and not _instance.is_done()


## play stops any existing playback, plays the configured event, applies covered params
## if the screen is currently covered, and emits `started`.
func play() -> StdSoundInstance:
	assert(event is StdSoundEvent, "invalid config; missing event")
	assert(
		_player is StdSoundEventPlayer,
		"invalid state; missing player",
	)

	if is_playing():
		stop()

	_instance = _player.play(event, fade_in)

	_instance.done.connect(_on_instance_done, CONNECT_ONE_SHOT)

	if _is_covered:
		_set_covered_params_enabled(true)

	started.emit(_instance)

	return _instance


## stop reverts covered params, stops playback with fade_out, and emits stopped.
func stop() -> void:
	if not is_playing():
		return

	_set_covered_params_enabled(false)

	Signals.disconnect_safe(_instance.done, _on_instance_done)

	_instance.stop(fade_out)
	_instance = null

	stopped.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	stop()


func _notification(what) -> void:
	match what:
		StdScreenManager.NOTIFICATION_SCREEN_COVERED:
			_is_covered = true
			if is_playing():
				_set_covered_params_enabled(true)

		StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED:
			_is_covered = false
			if is_playing():
				_set_covered_params_enabled(false)


func _ready() -> void:
	if not StdGroup.is_empty(StdSoundEventPlayer.GROUP_SOUND_PLAYER):
		_player = (
			StdGroup
			. get_sole_member(
				StdSoundEventPlayer.GROUP_SOUND_PLAYER,
			)
		)

	for param in covered_params:
		if param.enabled:
			(
				_logger
				. warn(
					(
						"Covered param has 'enabled' set to true;"
						+ " the emitter will override this."
					),
				)
			)

	if autoplay:
		play()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _set_covered_params_enabled(value: bool) -> void:
	for param in covered_params:
		param.enabled = value
		if is_playing():
			param.apply_to_event_instance(_instance)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_instance_done() -> void:
	# NOTE: The instance's bus is still valid here (signal connection order guarantees
	# `pool.reclaim` runs first, but the instance ref keeps the bus alive). Calling
	# `apply_to_event_instance` resets the param's internal state (`_effect`/`_index`),
	# preventing stale refs on the next call to `play`.
	for param in covered_params:
		if param.enabled:
			param.enabled = false
			param.apply_to_event_instance(_instance)

	_instance = null
	stopped.emit()
