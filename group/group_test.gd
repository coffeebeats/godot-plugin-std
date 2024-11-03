##
## Tests pertaining to the 'Group' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- TEST METHODS -------------------------------------------------------------------- #


func test_group_with_id_returns_same_instance():
	# Given: A new group is referenced.
	var group := Group.with_id(&"group-id")

	# When: That same group is accessed again.
	var got := Group.with_id(&"group-id")

	# Then: The two groups are the same instance.
	assert_same(got, group)


func test_group_add_member_uniquely_adds_value():
	# Given: A new group is referenced.
	var group := Group.with_id(&"group-id")

	# Given: Signals are monitored.
	watch_signals(group)

	# Given: A new member object.
	var member := RefCounted.new()

	# When: The new member is added to the group.
	var got := group.add_member(member)

	# Then: It's correctly detected as a new member.
	assert_true(got)

	# Then: That member is returned when members are listed.
	assert_eq(group.list_members(), [member])

	# Then: The member addition signal is emitted.
	assert_signal_emit_count(group, "member_added", 1)
	assert_signal_emitted_with_parameters(group, "member_added", [member])

	# When: That same member is added.
	got = group.add_member(member)

	# Then: It's no longer considered a new member.
	assert_false(got)

	# Then: That member is returned when members are listed.
	assert_eq(group.list_members(), [member])

	# Then: The member additional signal did not emit again.
	assert_signal_emit_count(group, "member_added", 1)


func test_group_remove_member_correctly_deletes_value():
	# Given: A new group is referenced.
	var group := Group.with_id(&"group-id")

	# Given: Signals are monitored.
	watch_signals(group)

	# Given: A new member object.
	var member := RefCounted.new()

	# When: That member, which isn't in the group, is removed.
	var got := group.remove_member(member)

	# Then: It's correctly detected to not be present.
	assert_false(got)

	# Then: The member removal signal is not emitted.
	assert_signal_not_emitted(group, "member_removed")

	# Given: That member is first added to the group.
	got = group.add_member(member)

	# When: That member, which now *is* in the group, is removed.
	got = group.remove_member(member)

	# Then: It's removal is correctly detected.
	assert_true(got)

	# Then: That member is not present.
	assert_eq(group.list_members(), [])

	# Then: The member removal signal is emitted.
	assert_signal_emit_count(group, "member_removed", 1)
	assert_signal_emitted_with_parameters(group, "member_removed", [member])


func test_group_clear_members_deletes_all_members():
	# Given: A new group is referenced.
	var group := Group.with_id(&"group-id")

	# Given: Signals are monitored.
	watch_signals(group)

	# Given: Three new member objects.
	var members := [
		RefCounted.new(),
		RefCounted.new(),
		RefCounted.new(),
	]

	# Given: Each member is added to the group.
	for member in members:
		group.add_member(member)

	# When: Members are cleared.
	group.clear_members()

	# Then: No members remain in the group.
	assert_eq(group.list_members(), [])

	# Then: Removal signals were emitted for each member.
	assert_signal_emit_count(group, "member_removed", 3)
	for i in len(members):
		assert_signal_emitted_with_parameters(group, "member_removed", [members[i]], i)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	# HACK: Clear the global 'Group' index before each test.
	Group._groups = {}
