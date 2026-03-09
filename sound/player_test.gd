##
## std/sound/player_test.gd
##
## Tests pertaining to `StdSoundEventPlayer`.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_play_returns_valid_instance():
	# Given: A sound player with a pool.
	var player := _create_player()
	var event := _create_event()

	# When: A sound is played.
	var instance := player.play(event)

	# Then: A valid, non-done instance is returned.
	assert_not_null(instance)
	assert_false(instance.is_done())


func test_play_tracks_active():
	# Given: A sound player with a pool.
	var player := _create_player()
	var event := _create_event()

	# When: A sound is played.
	player.play(event)

	# Then: The player is tracked as active.
	assert_eq(player._active_instances.size(), 1)


func test_play_multiple_tracks_all():
	# Given: A sound player with pool size 4.
	var player := _create_player(4)

	# When: Three sounds are played.
	player.play(_create_event())
	player.play(_create_event())
	player.play(_create_event())

	# Then: All three are tracked.
	assert_eq(player._active_instances.size(), 3)


func test_done_cleans_active():
	# Given: A sound playing.
	var player := _create_player()
	var instance := player.play(_create_event())

	# When: The instance completes.
	instance.stop()

	# Then: No active instances remain.
	assert_eq(player._active_instances.size(), 0)


func test_pool_exhausted_returns_null():
	# Given: A player with pool size 1 and no active sounds.
	var player := _create_player(1)
	var first := player.play(_create_event())

	# Given: The first sound completes, freeing the slot.
	first.stop()

	# Given: The slot is reclaimed but then claimed again.
	var second := player.play(_create_event())
	assert_not_null(second)

	# When: Another sound tries to play (pool full, same priority).
	var result := player.play(_create_event())

	# Then: Null is returned.
	assert_null(result)


func test_steals_lower_priority():
	# Given: A player with pool size 1.
	var player := _create_player(1)

	# Given: A low-priority sound playing.
	var low := _create_event(0)
	var low_instance := player.play(low)
	assert_not_null(low_instance)

	# When: A higher-priority sound is played.
	var high := _create_event(1)
	var high_instance := player.play(high)

	# Then: The low-priority sound was stolen.
	assert_true(low_instance.is_done())

	# Then: The high-priority sound is playing.
	assert_not_null(high_instance)


func test_returns_null_when_no_stealable():
	# Given: A player with pool size 1 and a high-priority sound playing.
	var player := _create_player(1)
	player.play(_create_event(1))

	# When: A lower-priority sound tries to play.
	var result := player.play(_create_event(0))

	# Then: Null is returned.
	assert_null(result)


func test_equal_priority_is_not_stealable():
	# Given: A player with pool size 1 and a sound at priority 0.
	var player := _create_player(1)
	player.play(_create_event(0))

	# When: Another sound at the same priority tries to play.
	var result := player.play(_create_event(0))

	# Then: Null is returned (equal priority is not stealable).
	assert_null(result)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_event(priority: int = 0) -> StdSoundEvent1D:
	var event := StdSoundEvent1D.new()

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 1.0

	event.stream = stream
	event.priority = priority

	var bus := StdAudioBusStatic.new()
	bus.name = &"Master"
	event.bus = bus

	return event


func _create_player(pool_size: int = 4) -> StdSoundEventPlayer:
	var player := StdSoundEventPlayer.new()

	var pool := StdAudioStreamPlayerPool1D.new()
	pool.size = pool_size

	player.pool_1d = pool
	player.add_child(pool)
	add_child_autofree(player)

	return player
