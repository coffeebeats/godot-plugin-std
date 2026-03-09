##
## std/sound/group_test.gd
##
## Tests pertaining to `StdSoundGroup`.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_can_play_respects_max():
	# Given: A group with max_audible = 1.
	var group := StdSoundGroup.new()
	group.max_audible = 1

	# Then: Initially, it can play.
	assert_true(group.can_play())

	# When: An instance is added.
	var instance := _create_instance(true)
	group.add(instance)

	# Then: It can no longer play.
	assert_false(group.can_play())


func test_rejects_finite_at_max():
	# Given: A group at capacity (max_audible = 1).
	var group := StdSoundGroup.new()
	group.max_audible = 1

	var first := _create_instance(true)
	group.add(first)

	# When: A finite (non-looping) instance is added.
	var finite := _create_instance(false)
	var result := group.add(finite)

	# Then: The addition is rejected.
	assert_false(result)

	# Then: The finite instance was stopped.
	assert_true(finite.is_done())


func test_overflows_looping():
	# Given: A group at capacity (max_audible = 1).
	var group := StdSoundGroup.new()
	group.max_audible = 1

	var first := _create_instance(true)
	group.add(first)

	# When: A looping instance is added.
	var looping := _create_instance(true)
	var result := group.add(looping)

	# Then: It is accepted into overflow.
	assert_true(result)
	assert_eq(group._overflow.size(), 1)


func test_promotes_on_done():
	# Given: A group at capacity with one overflow instance.
	var group := StdSoundGroup.new()
	group.max_audible = 1

	var first := _create_instance(true)
	group.add(first)

	var second := _create_instance(true)
	group.add(second)

	# When: The first instance completes.
	first.stop()

	# Then: The overflow instance is promoted.
	assert_eq(group._playing.size(), 1)
	assert_eq(group._overflow.size(), 0)


func test_mute_unmute_stacking():
	# Given: A group.
	var group := StdSoundGroup.new()

	var instance := _create_instance(true)
	group.add(instance)

	# When: Muted twice.
	group.mute()
	group.mute()

	# When: Unmuted once.
	group.unmute()

	# Then: Still muted (needs one more unmute).
	assert_true(instance._mute > 0)

	# When: Unmuted again.
	group.unmute()

	# Then: No longer muted.
	assert_eq(instance._mute, 0)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_instance(looping: bool) -> StdSoundInstance:
	var instance := StdSoundInstance.new()

	var wav := AudioStreamWAV.new()
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	instance.stream = wav

	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child_autofree(player)
	instance.player = player

	return instance
