##
## std/sound/pool_1d.gd
##
## StdAudioStreamPlayerPool2D is an object pool of `AudioStreamPlayer2D` nodes.
##

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

class_name StdAudioStreamPlayerPool2D
extends "pool.gd"


func _create_object() -> Variant:
	var player := AudioStreamPlayer2D.new()
	add_child(player, false)

	return player


func _on_reclaim(object: Variant) -> void:
	var player: AudioStreamPlayer2D = object
	assert(player is AudioStreamPlayer2D, " invalid argument; wrong type")

	for connection in player.finished.get_connections():
		player.finished.disconnect(connection["callable"])

	if player.playing:
		player.stop()


func _reset_object(object: Variant) -> void:
	var player: AudioStreamPlayer2D = object
	assert(player is AudioStreamPlayer2D, " invalid argument; wrong type")

	player.area_mask = 1
	player.attenuation = 1.0
	player.autoplay = false
	player.bus = &"Master"
	player.max_distance = 2000.0
	player.max_polyphony = 1
	player.panning_strength = 1.0
	player.pitch_scale = 1.0
	player.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
	player.playing = false
	player.stream = null
	player.stream_paused = false
	player.volume_db = 0.0


func _validate_object(object: Variant) -> bool:
	if not object is AudioStreamPlayer2D:
		return false

	return object in get_children()
