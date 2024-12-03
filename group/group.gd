##
## std/group/group.gd
##
## `StdGroup` is a collection of 'Object' instances which relate in some way. Largely
## inspired by node groups, this implementation removes a few limitations:
## 	 1. These groups aren't limited to 'Node' instances - any 'Variant' can be added.
##   2. Groups inherit 'RefCounted', but are globally unique and can thus be accessed in
##   	any context (even without a scene tree reference).
##	 3. Membership operations emit a signal, allowing reactive programming.
##

class_name StdGroup
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## member_added is emitted when the specified member joins the group.
signal member_added(member: Variant)

## member_removed is emitted when the specified member leaves the group.
signal member_removed(member: Variant)

# -- DEFINITION ---------------------------------------------------------------------- #

## _groups is a static collection of all group instances. Because group names are keys,
## groups can be uniquely identified and accessed from any context.
static var _groups: Dictionary = {}

# -- INITIALIZATION ------------------------------------------------------------------ #

## id is the globally unique identifier for the group.
var id: StringName = ""

## _members is the collection of members within the group.
var _members: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_sole_member returns the sole member of a group. If `0` or more than `1` member
## exists, `null` will be returned and an error pushed.
static func get_sole_member(group_id: StringName) -> Variant:
	var group := with_id(group_id)
	if not group:
		assert(false, "invalid argument; missing group")
		return null

	var members := group.list_members()
	if len(members) != 1:
		assert(false, "invalid state; incorrect number of members")
		return null

	return members[0]

## is_empty returns whether the specified group is empty (i.e. has no members).
static func is_empty(group_id: StringName) -> bool:
	var group := with_id(group_id)
	if not group:
		return true

	var members := group.list_members()
	return members.is_empty()


## with_id access the group with the provided identifier, creating one if it does not
## exist. Groups should *always* be referenced using this method as it ensures duplicate
## groups (which wouldn't be connected) aren't created.
static func with_id(group_id: StringName) -> StdGroup:
	if group_id in _groups:
		assert(_groups[group_id] is StdGroup, "invalid state: expected group")
		return _groups[group_id]

	var group := StdGroup.new()
	group.id = group_id

	_groups[group_id] = group
	return group


## add_member adds the provided 'Variant' to the set of members and returns whether it
## was just added. Nothing happens if the member is already present.
##
## NOTE: The 'member' value must be hashable.
func add_member(member: Variant) -> bool:
	if member in _members:
		return false

	_members[member] = true

	member_added.emit(member)

	return true


## clear_members removes all members in the group.
func clear_members() -> void:
	var members := list_members()
	for member in members:
		remove_member(member)


## list_members returns the set of members present in the group.
func list_members() -> Array[Variant]:
	return _members.keys()


## remove_member removes the provided member from the group and returns whether it was
## present. Nothing happens if the member is not part of the group.
##
## NOTE: The 'member' value must be hashable.
func remove_member(member: Variant) -> bool:
	if not _members.erase(member):
		return false

	member_removed.emit(member)
	return true
