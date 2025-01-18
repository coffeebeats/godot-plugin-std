##
## Tests pertaining to the `StdConfigWriter` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class StdConfigWriterTest:
	extends StdConfigWriter

	var path: String = ""

	func _get_filepath() -> String:
		return path


# -- INITIALIZATION ------------------------------------------------------------------ #

## path_test_dir is the path to the case-specific testing directory; this will be
## removed at the end of each test.
var path_test_dir: String

var writer: StdConfigWriterTest = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_writer_load_config_succeeds_when_file_does_not_exist():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: An empty `Config` instance.
	var config := Config.new()

	# Given: A config writer writing to a file that doesn't exist.
	writer = StdConfigWriterTest.new()
	writer.path = path
	add_child(writer)

	# When: The config is loaded from disk.
	var err := writer.load_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The config instance is empty.
	assert_true(not config._data)  # No need to lock config here.

	# Then: The writer created the file.
	assert_true(FileAccess.file_exists(path))


func test_config_writer_load_config_succeeds_when_path_is_nested():
	# Given: A test file path.
	var path := path_test_dir.path_join("directory/does/not/exist/test.dat")

	# Given: An empty `Config` instance.
	var config := Config.new()

	# Given: A config writer writing to a file that doesn't exist.
	writer = StdConfigWriterTest.new()
	writer.path = path
	add_child(writer)

	# When: The config is loaded from disk.
	var err := writer.load_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The config instance is empty.
	assert_true(not config._data)  # No need to lock config here.

	# Then: The writer created the file.
	assert_true(FileAccess.file_exists(path))


func test_config_writer_load_config_reads_existing_file_data():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: Non-empty config data is stored in that file.
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_buffer(var_to_bytes({&"category": {&"key": "value"}}))
	file.close()

	# Given: An empty `Config` instance.
	var config := Config.new()

	# Given: A config writer writing to a file that doesn't exist.
	writer = StdConfigWriterTest.new()
	writer.path = path
	add_child(writer)

	# When: The config is loaded from disk.
	var err := writer.load_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The config instance matches expectations
	assert_eq(config.get_string(&"category", &"key", ""), "value")

	# Then: The file's contents match expectations.
	var got := FileAccess.get_file_as_bytes(path)
	assert_eq(FileAccess.get_open_error(), OK)
	assert_eq(bytes_to_var(got), config._data)


func test_config_writer_store_config_succeeds_when_file_does_not_exist():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: A non-empty `Config` instance.
	var config := Config.new()
	config.set_string(&"category", &"key", "value")

	# Given: A config writer writing to a file that doesn't exist.
	writer = StdConfigWriterTest.new()
	writer.path = path
	add_child(writer)

	# When: The config is written to disk.
	var err := writer.store_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The on-disk contents match expectations.
	var got := Config.new()
	err = writer.load_config(got).wait()
	assert_eq(err, OK)
	assert_eq_deep(got._data, config._data)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	remove_child(writer)
	writer.free()

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
