##
## std/sound/mix_snapshot_test.gd
##
## Tests pertaining to `StdMixSnapshot` and `StdMixSnapshotInstance`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instances: Array[StdMixSnapshotInstance] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_apply_creates_valid_instance():
	# Given: A snapshot with one override on the Master bus.
	var snapshot := _create_snapshot()

	# When: Applied.
	var instance := _apply(snapshot)

	# Then: The instance is valid.
	assert_true(instance.is_valid())


func test_effects_appear_on_bus():
	# Given: A snapshot targeting the Master bus.
	var snapshot := _create_snapshot()
	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)

	# When: Applied.
	_apply(snapshot)

	# Then: An effect was added to the bus.
	assert_eq(
		AudioServer.get_bus_effect_count(bus_index),
		count_before + 1,
	)


func test_reset_clears_effects():
	# Given: An applied snapshot.
	var snapshot := _create_snapshot()
	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)
	var instance := _apply(snapshot)

	# When: Reset.
	instance.reset()

	# Then: Effects are removed.
	assert_eq(
		AudioServer.get_bus_effect_count(bus_index),
		count_before,
	)
	assert_false(instance.is_valid())


func test_intensity_modulates_blend():
	# Given: An applied snapshot with a property.
	var snapshot := _create_snapshot(&"cutoff_hz", 20500.0, 1400.0)
	var instance := _apply(snapshot)

	# When: Intensity is set to 0.0.
	instance.set_intensity(0.0)

	# Then: The effect property is at value_off.
	var effect_instance: StdSoundBusEffectInstance = instance._instances[0]
	assert_almost_eq(
		effect_instance._resource.get(&"cutoff_hz") as float,
		20500.0,
		0.01,
	)


func test_multiple_snapshots_stack():
	# Given: Two snapshots on the same bus.
	var a := _create_snapshot()
	var b := _create_snapshot()
	var bus_index := 0
	var count_before := AudioServer.get_bus_effect_count(bus_index)

	# When: Both are applied.
	var ia := _apply(a)
	var _ib := _apply(b)

	# Then: Two effects are on the bus.
	assert_eq(
		AudioServer.get_bus_effect_count(bus_index),
		count_before + 2,
	)

	# When: One is reset.
	ia.reset()

	# Then: One effect remains.
	assert_eq(
		AudioServer.get_bus_effect_count(bus_index),
		count_before + 1,
	)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	for instance in _instances:
		if instance.is_valid():
			instance.reset()

	_instances.clear()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply(snapshot: StdMixSnapshot) -> StdMixSnapshotInstance:
	var instance := snapshot.apply(self)
	_instances.append(instance)

	return instance


func _create_snapshot(
	prop: StringName = &"",
	off: float = 0.0,
	on: float = 0.0,
) -> StdMixSnapshot:
	var bus := StdAudioBusStatic.new()
	bus.name = &"Master"

	var bus_effect := StdSoundBusEffect.new()
	bus_effect.effect = AudioEffectLowPassFilter.new()

	if prop != &"":
		var p := StdSoundBusEffectProperty.new()
		p.property = prop
		p.value_off = off
		p.value_on = on
		bus_effect.properties = [p]

	var override := StdMixSnapshotOverride.new()
	override.bus = bus
	override.bus_effect = bus_effect

	var snapshot := StdMixSnapshot.new()
	snapshot.overrides = [override]

	return snapshot
