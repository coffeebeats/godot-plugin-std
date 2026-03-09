##
## std/sound/group.gd
##
## StdSoundGroup defines a "scope" with rules which associated sound instances must
## adhere to. In effect, attaching a sound group to a sound event allows for controlling
## the number of simultaneous audible instances and group-wide mutes.
##

class_name StdSoundGroup
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## added is emitted when a new sound instance joins the group.
signal added(instance: StdSoundInstance)

## removed is emitted when sound instance leaves the group.
signal removed(instance: StdSoundInstance)

# -- CONFIGURATION ------------------------------------------------------------------- #

## max_audible is the maximum number of sounds in the group that can be playing at once.
## any new sounds that join the group after this limit is reached will be muted until
## space within the group opens up.
@export var max_audible: int = -1

## resume_playing_on_unmute controls whether sounds that were muted via this group's
## `mute` method resume audible playback when `unmute` is called. This is helpful for
## circumstances where the mute functions more as a "prevent new sounds" behavior.
@export var resume_playing_on_unmute: bool = true

## promotion_fade is an optional tween curve applied when a muted overflow instance is
## promoted to audible playback.
@export var promotion_fade: StdTweenCurve = null

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/sound/group")  # gdlint:ignore=class-definitions-order,max-line-length

var _mute: int = 0
var _overflow: Array[StdSoundInstance] = []
var _playing: Array[StdSoundInstance] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## add adds the provided sound instance to the group. It will be removed once its
## playback completes.
func add(instance: StdSoundInstance) -> bool:
	assert(instance is StdSoundInstance, "invalid argument; missing instance")
	assert(not instance.is_done(), "invalid input; instance is already done")

	if _mute > 0:
		instance.mute()

	if not can_play():
		if not _is_looping(instance):
			instance.stop()
			return false

		instance.mute()
		_overflow.append(instance)
	else:
		_playing.append(instance)

	instance.done.connect(_on_instance_done.bind(instance), CONNECT_ONE_SHOT)
	added.emit(instance)

	return true


## can_play returns whether there is available room for a new instance to join.
func can_play() -> bool:
	return true if (max_audible < 0) else (_playing.size() < max_audible)


## get_count_playing returns the number of instances in the group currently playing.
func get_count_playing() -> int:
	return _playing.size()


## mute silences all playback within the sound group. Note that this can be called
## multiple times, but `unmute` must then be called an equal number of times for sound
## to be audible again.
func mute() -> void:
	var was_muted: bool = _mute > 0
	_mute += 1

	_logger.debug("Muting sound group.", {&"count": _mute})

	if was_muted:
		return

	for instance in _playing:
		instance.mute()

	for instance in _overflow:
		instance.mute()


## unmute removes a previous mute, allowing playback to be audible again. Note that for
## this method to take effect, it must be called an equal number of times to `mute`.
func unmute() -> void:
	var was_muted: bool = _mute > 0
	_mute = max(_mute - 1, 0)

	_logger.debug("Unmuting sound group.", {&"count": _mute})

	if not was_muted or _mute > 0:
		return

	if not resume_playing_on_unmute:
		return

	for instance in _playing:
		instance.unmute()

	for instance in _overflow:
		instance.unmute()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_instance_done(instance: StdSoundInstance) -> void:
	assert(instance is StdSoundInstance, "invalid argument; missing instance")

	var erased := _erase_from(_playing, instance)
	assert(erased, "invalid state; instance not found")

	# NOTE: Only playing instances free up a slot for promotion.
	if erased:
		_promote_overflow()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _is_looping(instance: StdSoundInstance) -> bool:
	var stream := instance.stream
	if stream is AudioStreamWAV:
		return stream.loop_mode != AudioStreamWAV.LOOP_DISABLED

	if &"loop" in stream:
		return stream.get(&"loop") as bool

	return false


func _erase_from(list: Array[StdSoundInstance], instance: StdSoundInstance) -> bool:
	var index := list.find(instance)
	if index < 0:
		return false

	list.remove_at(index)
	removed.emit(instance)

	return true


func _promote_overflow() -> void:
	while _overflow and can_play():
		var next: StdSoundInstance = _overflow.pop_front()

		next.unmute()
		_playing.append(next)

		if promotion_fade and next.player.is_inside_tree():
			var target: float = next.player.volume_db
			next.player.volume_db = target + StdSoundInstance.FADE_VOLUME_DB

			var tween := next.player.get_tree().create_tween()
			promotion_fade.tween_property(tween, next.player, ^"volume_db", target)
