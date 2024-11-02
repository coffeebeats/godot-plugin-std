##
## Tests pertaining to the 'FileSyncer' class.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

## path_test_dir is the path to the case-specific testing directory; this will be
## removed at the end of each test.
var path_test_dir: String

# -- TEST METHODS -------------------------------------------------------------------- #


func test_file_syncer_open_creates_file():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: A file syncer writing to a file that doesn't exist.
	var file_syncer := FileSyncer.new()
	file_syncer.path = path
	file_syncer.open_on_tree_entered = false
	add_child_autofree(file_syncer)

	# Given: Signal emissions are monitored.
	watch_signals(file_syncer)

	# When: The file is opened.
	var err := file_syncer.open()

	# Then: The file is successfully opened.
	assert_eq(err, OK)

	# Then: The 'error' signal was not emitted.
	assert_signal_not_emitted(file_syncer, "error")

	# Then: The file exists.
	assert_true(FileAccess.file_exists(path))

	# Then: The 'file_opened' signal was emitted.
	assert_signal_emit_count(file_syncer, "file_opened", 1)
	assert_signal_emitted_with_parameters(file_syncer, "file_opened", [])


func test_file_syncer_open_creates_file_nested_in_missing_directory():
	# Given: A test file path.
	var path := path_test_dir.path_join("directory/does/not/exist/test.dat")

	# Given: A file syncer writing to a file that doesn't exist.
	var file_syncer := FileSyncer.new()
	file_syncer.path = path
	file_syncer.open_on_tree_entered = false
	add_child_autofree(file_syncer)

	# Given: Signal emissions are monitored.
	watch_signals(file_syncer)

	# When: The file is opened.
	var err := file_syncer.open()

	# Then: The file is successfully opened.
	assert_eq(err, OK)

	# Then: The 'error' signal was not emitted.
	assert_signal_not_emitted(file_syncer, "error")

	# Then: The file exists.
	assert_true(FileAccess.file_exists(path))

	# Then: The 'file_opened' signal was emitted.
	assert_signal_emit_count(file_syncer, "file_opened", 1)
	assert_signal_emitted_with_parameters(file_syncer, "file_opened", [])


func test_file_syncer_set_value_updates_file():
	# Given: A test file path.
	var path := path_test_dir.path_join("directory/does/not/exist/test.dat")

	# Given: A debounce duration in seconds.
	var duration := 0.1

	# Given: A file syncer writing to a file that doesn't exist.
	var file_syncer := FileSyncer.new()
	file_syncer.path = path
	file_syncer.open_on_tree_entered = false
	file_syncer.duration = duration
	file_syncer.duration = duration
	add_child_autofree(file_syncer)

	# Given: Signal emissions are monitored.
	watch_signals(file_syncer)

	# Given: The file is opened.
	var err := file_syncer.open()
	assert_eq(err, OK)

	# Given: Contents to be written to disk.
	var want := var_to_bytes([1, 2, 3])

	# When: The value is written to disk.
	file_syncer.store_bytes(want)

	# Then: The 'write_requested' signal is emitted.
	assert_signal_emit_count(file_syncer, "write_requested", 1)

	# Then: The write has not yet occurred.
	assert_signal_not_emitted(file_syncer, "write_flushed")

	# Given: The debounce duration elapses.
	simulate(file_syncer, 1, duration, true)
	simulate(file_syncer._debounce, 1, duration, true)

	# Then: The write was flushed.
	assert_signal_emit_count(file_syncer, "write_flushed", 1)

	# Then: The file's contents match expectations.
	var got := FileAccess.get_file_as_bytes(path)
	assert_eq(FileAccess.get_open_error(), OK)
	assert_eq(got, want)

	# Then: The syncer reads contents successfully.
	assert_eq(file_syncer.read_bytes(), want)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	var to_search: Array[String] = [path_test_dir]
	while to_search:
		var path_dir: String = to_search.pop_back()

		var dir := DirAccess.open(path_dir)
		assert_not_null(dir)

		dir.include_hidden = true
		dir.include_navigational = false

		for filepath in dir.get_files():
			DirAccess.remove_absolute(path_dir.path_join(filepath))

		var directories := dir.get_directories()
		if not directories:
			assert_eq(DirAccess.remove_absolute(path_dir), OK)
			continue

		to_search.append(path_dir)

		for directory in dir.get_directories():
			to_search.append(path_dir.path_join(directory))


func before_each():
	path_test_dir = "user://".path_join("test-%d" % randi())
	assert_eq(DirAccess.make_dir_recursive_absolute(path_test_dir), OK)


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
