##
## std/sound/instance.gd
##
## StdSoundInstance is a single occurrence of a source audio stream being played, either
## to completion or until manual termination. This handle can be used to modulate the
## sound while the audio is playing. However, once the instance is complete (i.e. `done`
## has been emitted), no further modulation is allowed.
##
## NOTE: It is not safe to modify the `player` node after playback completes, as it will
## have been returned to an audio player pool
##

class_name StdSoundInstance
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## done is emitted when the audio playback has completed, whether by finishing the
## source audio stream or manual termination.
signal done

# -- DEFINITIONS --------------------------------------------------------------------- #

## FADE_VOLUME_DB is the volume offset used as the start/end point for fade transitions.
## Chosen to be low enough to sound smooth but high enough to avoid pop on short fades.
const FADE_VOLUME_DB := -24.0

## MUTE_VOLUME_DB describes the relative loudness value that will be used to mute audio.
const MUTE_VOLUME_DB := 120.0

# -- CONFIGURATION ------------------------------------------------------------------- #

## stream is the source audio stream to be played.
var stream: AudioStream = null

## bus defines the audio bus to which sound will be routed.
var bus: StdAudioBus = null

## params is a list of parameters which modulate the audio playback.
var params: Array[StdSoundParam] = []

## group is an optional sound group to which the audio will belong.
var group: StdSoundGroup = null

## player is a reference to the player node that will be playing the source audio.
var player: Node = null

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/sound/instance")  # gdlint:ignore=class-definitions-order,max-line-length

var _is_done: bool = false
var _mute: int = 0
var _tween: Tween = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_done returns whether the instance has completed playback.
func is_done() -> bool:
	return _is_done


## mute silences this sound instance, preventing it from being audible in the mix. Safe
## to call multiple times, though it must be unmuted an equal number of times to be
## audible again.
func mute() -> void:
	assert(not _is_done, "invalid state; instance is done")
	assert(player is Node, "invalid state; missing player")

	var was_muted: bool = _mute > 0
	_mute += 1

	if was_muted:
		return

	player.volume_db -= MUTE_VOLUME_DB


## start begins audio playback. Must be called as the associated audio players are not
## configured to auto-play.
func start(
	fade_curve: StdTweenCurve = null,
	start_db: float = FADE_VOLUME_DB,
) -> void:
	assert(player is Node, "invalid state; missing player")
	assert(not _is_done and not player.playing, "invalid state; already started")

	_logger.debug("Playing sound event.", {&"stream": stream.resource_path})

	if fade_curve and fade_curve.duration > 0.0:
		assert(
			fade_curve.duration < stream.get_length(),
			"invalid config; fade exceeds stream",
		)

		var target: float = player.volume_db
		player.volume_db = start_db

		assert(not _tween, "invalid state; found dangling tween")
		_tween = player.get_tree().create_tween()

		fade_curve.tween_property(_tween, player, ^"volume_db", target)

		_tween.tween_callback(func(): _tween = null)

	player.play()


## stop terminates audio playback, rendering this instance invalid/complete. Safe to
## call multiple times, even after audio playback has completed.
func stop(
	fade_curve: StdTweenCurve = null,
	end_db: float = FADE_VOLUME_DB,
) -> void:
	if _is_done:
		return

	if _tween:
		_tween.kill()
		_tween = null

	var fade_out := fade_curve.duration if fade_curve else 0.0

	if player.playing and fade_out <= 0.0:
		player.stop()

	if not player.playing:
		done.emit()
		return

	_logger.debug("Stopping sound event.", {&"stream": stream.resource_path})

	if fade_curve and fade_out > 0.0:
		assert(
			(
				fade_out
				< (
					stream.get_length()
					- player.get_playback_position()
					+ AudioServer.get_time_since_last_mix()
				)
			),
			"invalid config; fade exceeds stream",
		)

		_tween = player.get_tree().create_tween()

		fade_curve.tween_property(_tween, player, ^"volume_db", end_db)

		_tween.tween_callback(player.stop)
		_tween.tween_callback(done.emit)
		_tween.tween_callback(func(): _tween = null)


## unmute requests this sound instance to be audible after previously being muted. Note
## that an equal number of unmute requests to mute requests must be sent before the
## sound will actually be unmuted.
func unmute() -> void:
	assert(not _is_done, "invalid state; instance is done")
	assert(player is Node, "invalid state; missing player")

	var was_muted: bool = _mute > 0
	_mute = max(_mute - 1, 0)

	if not was_muted or _mute > 0:
		return

	player.volume_db += MUTE_VOLUME_DB


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	done.connect(func(): _is_done = true, CONNECT_ONE_SHOT)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_param_update(p: StdSoundParam) -> void:
	assert(not _is_done, "invalid state; instance is already done")
	p.apply_to_event_instance(self)
