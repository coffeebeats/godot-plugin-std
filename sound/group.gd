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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _mute: int = 0
var _playing: Array[StdSoundInstance] = []
var _virtual: Array[StdSoundInstance] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## add adds the provided sound instance to the group. It will be removed once its
## playback completes.
func add(instance: StdSoundInstance) -> bool:
	assert(instance is StdSoundInstance, "invalid argument; missing instance")
	assert(not instance.is_done(), "invalid input; instance is already done")

	instance.done.connect(_on_instance_done.bind(instance), CONNECT_ONE_SHOT)

	if _mute > 0:
		instance.mute()

	if not can_play():
		instance.mute()
		_virtual.append(instance)
	else:
		_playing.append(instance)

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

	if was_muted:
		return

	for instance in _playing:
		instance.mute()

	for instance in _virtual:
		instance.mute()


## unmute removes a previous mute, allowing playback to be audible again. Note that for
## this method to take effect, it must be called an equal number of times to `mute`.
func unmute() -> void:
	var was_muted: bool = _mute > 0
	_mute = max(_mute - 1, 0)

	if not was_muted or _mute > 0:
		return

	for instance in _playing:
		instance.unmute()

	for instance in _virtual:
		instance.unmute()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_instance_done(instance: StdSoundInstance) -> void:
	assert(instance is StdSoundInstance, "invalid argument; missing instance")
	assert(
		instance in _playing or instance in _virtual,
		"invalid argument; instance not reserved",
	)

	var index := _playing.find(instance)
	if index > -1:
		_playing.erase(instance)
		removed.emit(instance)

	index = _virtual.find(instance)
	if index > -1:
		_virtual.erase(instance)
		removed.emit(instance)

	# FIXME: This behavior sounds bad - either improve it via fade-in or remove it.
	while _virtual and can_play():
		var next: StdSoundInstance = _virtual.pop_front()
		if not next:
			break

		next.unmute()
		_playing.append(next)
