# meta-name: Resource
# meta-default: true
# meta-space-indent: 4

##
## Insert 'Resource' description here.
##

class_name Group
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

signal member_added(member: Variant)

signal member_removed(member: Variant)

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

var name: StringName = ""

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _groups: Dictionary = {}

var _members: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


static func with_name(group_name: StringName) -> Group:
	if group_name in _groups:
		assert(_groups[group_name] is Group, "invalid state: expected group")
		return _groups[group_name]

	var group := Group.new()
	group.name = group_name

	_groups[group_name] = group
	return group


func add_member(member: Variant) -> bool:
	if member in _members:
		return false

	_members[member] = true

	member_added.emit(member)

	return true


func list_members() -> Array[Variant]:
	return _members.keys()


func remove_member(member: Variant) -> bool:
	if not _members.erase(member):
		return false

	member_removed.emit(member)
	return true

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

#func _init() -> void:
#	pass

#func _setup_local_to_scene() -> void:
#	pass

#func _to_string() -> void:
#	pass

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
