##
## screen/screen_test.gd
##
## Tests pertaining to `StdScreen`.
##

extends GutTest

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func test_get_dependency_paths_empty_returns_empty():
	# Given: A screen with no dependencies configured.
	var screen := StdScreen.new()

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: The result is empty.
	assert_eq(paths, PackedStringArray())


func test_get_dependency_paths_scenes_only():
	# Given: A screen with only 'dependency_scenes' set.
	var screen := StdScreen.new()
	screen.dependency_scenes = PackedStringArray(["res://a.tscn", "res://b.tscn"])

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: Both scene paths are returned.
	assert_eq(
		paths,
		PackedStringArray(["res://a.tscn", "res://b.tscn"]),
	)


func test_get_dependency_paths_screens_only():
	# Given: A screen with only 'dependency_screens' set.
	var dep := StdScreen.new()
	dep.scene_path = "res://dep.tscn"

	var screen := StdScreen.new()
	screen.dependency_screens = [dep]

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: The referenced screen's scene path is returned.
	assert_eq(paths, PackedStringArray(["res://dep.tscn"]))


func test_get_dependency_paths_combined():
	# Given: A screen with both dependency sources.
	var dep := StdScreen.new()
	dep.scene_path = "res://dep.tscn"

	var screen := StdScreen.new()
	screen.dependency_scenes = PackedStringArray(["res://a.tscn"])
	screen.dependency_screens = [dep]

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: Paths from both sources are returned.
	assert_eq(
		paths,
		PackedStringArray(["res://a.tscn", "res://dep.tscn"]),
	)


func test_get_dependency_paths_deduplicates():
	# Given: A screen where the same path appears in both sources.
	var dep := StdScreen.new()
	dep.scene_path = "res://shared.tscn"

	var screen := StdScreen.new()
	screen.dependency_scenes = PackedStringArray(["res://shared.tscn"])
	screen.dependency_screens = [dep]

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: The duplicated path appears only once.
	assert_eq(paths, PackedStringArray(["res://shared.tscn"]))


func test_get_dependency_paths_recursive():
	# Given: A chain A -> B -> C.
	var c := StdScreen.new()
	c.scene_path = "res://c.tscn"

	var b := StdScreen.new()
	b.scene_path = "res://b.tscn"
	b.dependency_screens = [c]

	var a := StdScreen.new()
	a.dependency_screens = [b]

	# When: Dependency paths are resolved from A.
	var paths := a.get_dependency_paths()

	# Then: All transitive paths are returned.
	assert_eq(
		paths,
		PackedStringArray(["res://b.tscn", "res://c.tscn"]),
	)


func test_get_dependency_paths_diamond():
	# Given: A diamond: A -> B, A -> C -> B.
	var b := StdScreen.new()
	b.scene_path = "res://b.tscn"

	var c := StdScreen.new()
	c.scene_path = "res://c.tscn"
	c.dependency_screens = [b]

	var a := StdScreen.new()
	a.dependency_screens = [b, c]

	# When: Dependency paths are resolved from A.
	var paths := a.get_dependency_paths()

	# Then: B's path appears once; no error.
	assert_eq(
		paths,
		PackedStringArray(["res://b.tscn", "res://c.tscn"]),
	)


func test_get_dependency_paths_includes_attachments():
	# Given: A screen with both dependency and attachment scenes.
	var screen := StdScreen.new()
	screen.dependency_scenes = PackedStringArray(["res://a.tscn"])
	screen.attachment_scenes = PackedStringArray(["res://pusher.tscn"])

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: The attachment path is preloaded alongside the dependency.
	assert_eq(
		paths,
		PackedStringArray(["res://a.tscn", "res://pusher.tscn"]),
	)


func test_get_dependency_paths_deduplicates_attachments():
	# Given: A screen whose attachment is also a dependency of a referenced screen.
	var dep := StdScreen.new()
	dep.scene_path = "res://dep.tscn"
	dep.attachment_scenes = PackedStringArray(["res://pusher.tscn"])

	var screen := StdScreen.new()
	screen.attachment_scenes = PackedStringArray(["res://pusher.tscn"])
	screen.dependency_screens = [dep]

	# When: Dependency paths are resolved.
	var paths := screen.get_dependency_paths()

	# Then: The shared attachment path appears once.
	assert_eq(
		paths,
		PackedStringArray(["res://pusher.tscn", "res://dep.tscn"]),
	)


func test_get_dependency_paths_cycle_logs_error():
	# Given: A cycle: A -> B -> A.
	var a := StdScreen.new()
	var b := StdScreen.new()
	b.scene_path = "res://b.tscn"
	a.dependency_screens = [b]
	b.dependency_screens = [a]

	# When: Dependency paths are resolved from A.
	var paths := a.get_dependency_paths()

	# Then: The cycle is broken and B's scene path is still returned.
	assert_eq(paths, PackedStringArray(["res://b.tscn"]))

	# Then: An error was logged about the cycle.
	assert_push_error("Dependency cycle detected.")
