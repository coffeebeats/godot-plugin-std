##
## screen/manager/cache_test.gd
##
## Tests pertaining to the cache's check of whether a scene can be parked.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Cache := preload("cache.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_find_unparkable_with_3d_root_reports_root_class() -> void:
	# Given: A scene rooted in a `Node3D`.
	var scene: Node = autofree(Node3D.new())

	# When: The scene is checked for nodes parking would leave shown.
	var offenders := Cache.find_unparkable(scene)

	# Then: The root is reported by its class.
	assert_eq(offenders, PackedStringArray([".: Node3D"]))


func test_find_unparkable_with_3d_descendant_reports_descendant_class() -> void:
	# Given: A `Control` scene holding a `MeshInstance3D`.
	var scene: Node = autofree(Control.new())
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	scene.add_child(mesh)

	# When: The scene is checked for nodes parking would leave shown.
	var offenders := Cache.find_unparkable(scene)

	# Then: The descendant is reported by its path and class.
	assert_eq(offenders, PackedStringArray(["Mesh: MeshInstance3D"]))


func test_find_unparkable_with_2d_scene_reports_nothing() -> void:
	# Given: A `Control` scene holding a `Node2D`.
	var scene: Node = autofree(Control.new())
	scene.add_child(Node2D.new())

	# When: The scene is checked for nodes parking would leave shown.
	var offenders := Cache.find_unparkable(scene)

	# Then: Nothing is reported.
	assert_eq(offenders, PackedStringArray())
