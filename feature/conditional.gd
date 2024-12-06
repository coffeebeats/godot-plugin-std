##
## std/feature/conditional.gd
##
## StdConditional is a node which conditionally allows its children to enter the scene
## tree based on whether certain feature flags are set.
##

class_name StdConditional
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## allow is a list of feature flags (tested via `OS.has_feature`) which determine
## whether children `Node`s can enter the scene tree.
@export var allow: PackedStringArray

## allow_require_all controls whether the `allow` condition requires all features to be
## enabled (`true`) instead of just one of them (`false`).
@export var allow_require_all: bool = false

## include_internal determines whether to remove internal nodes from the scene tree when
## conditions are not met.
@export var include_internal: bool = true

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if not (
		Array(allow).all(OS.has_feature)
		if allow_require_all
		else Array(allow).any(OS.has_feature)
	):
		return _remove_all_children()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _remove_all_children() -> void:
	for child in get_children(include_internal):
		remove_child(child)
		child.queue_free()
