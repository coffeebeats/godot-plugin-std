##
## std/sound/event_2d.gd
##
## StdSoundEvent2D is a description of a sound positioned in 2D space, like game audio
## effects.
##

class_name StdSoundEvent2D
extends StdSoundEvent

# -- CONFIGURATION ------------------------------------------------------------------- #

## remote_transform is an absolute node path to a `RemoteTransform2D` that will be used
## to drive the position of the associated `AudioStreamPlayer2D`.
@export var remote_transform: NodePath = ^""

@export_subgroup("Player")

## area_mask sets the `area_mask` property on the associated `AudioStreamPlayer2D`.
@export var area_mask: int = 1

## attenuation sets the `attenuation` property on the associated `AudioStreamPlayer2D`.
@export var attenuation: float = 1.0

## max_distance sets the `max_distance` property on the associated
## `AudioStreamPlayer2D`.
@export var max_distance: float = 2000.0

## panning_strength sets the `panning_strength` property on the associated
## `AudioStreamPlayer2D`.
@export var panning_strength: float = 1.0

## pitch_scale sets the `pitch_scale` property on the associated `AudioStreamPlayer2D`.
@export var pitch_scale: float = 1.0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _configure(player: AudioStreamPlayer2D) -> void:
	assert(player is AudioStreamPlayer2D)
	assert(player.is_inside_tree())

	var viewport := player.get_viewport()
	assert(viewport is Viewport)

	var source := viewport.get_node(remote_transform)
	if not source is RemoteTransform2D:
		assert(false)
		return

	source.remote_path = source.get_path_to(player)

	player.area_mask = area_mask
	player.attenuation = attenuation
	player.autoplay = false
	player.bus = bus.get_bus_name()
	player.max_distance = max_distance
	player.max_polyphony = 1
	player.panning_strength = panning_strength
	player.pitch_scale = pitch_scale
	player.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
	player.playing = false
	player.stream = null
	player.stream_paused = false
	player.volume_db = volume_db
