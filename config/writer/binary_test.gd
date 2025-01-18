##
## Tests pertaining to the `StdBinaryConfigWriter` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## path_test_dir is the path to the case-specific testing directory; this will be
## removed at the end of each test.
var path_test_dir: String

var writer: StdBinaryConfigWriter = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_writer_load_config_reads_existing_file_data():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: A config writer writing to a file.
	writer = StdBinaryConfigWriter.new()
	writer.path = path
	add_child(writer)

	# Given: A non-empty `Config` instance.
	var config := Config.new()
	config.set_string(&"category", &"key", "value")

	# Given: Non-empty config data is stored in that file.
	var err := writer.store_config(config).wait()
	assert_eq(err, OK)

	# Given: The config instance is reset.
	config = Config.new()

	# When: The config is loaded from disk.
	err = writer.load_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The config instance matches expectations
	assert_eq(config.get_string(&"category", &"key", ""), "value")


func test_config_writer_load_config_reads_valid_tmp_file_data():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: A non-empty `Config` instance.
	var config := Config.new()
	config.set_string(&"category", &"key", "value")

	# Given: A config writer writing to a tmp file.
	writer = StdBinaryConfigWriter.new()
	writer.path = path + ".tmp"
	add_child(writer)

	# Given: Non-empty config data is stored in that file.
	var err := writer.store_config(config).wait()
	assert_eq(err, OK)

	# Given: The config writer is configured to the standard target path.
	writer.path = path

	# Given: The config instance is reset.
	config = Config.new()

	# When: The config is loaded from disk.
	err = writer.load_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The config instance matches expectations
	assert_eq(config.get_string(&"category", &"key", ""), "value")


func test_config_writer_load_config_skips_invalid_tmp_file_data():
	# Given: A test file path.
	var path := path_test_dir.path_join("test.dat")

	# Given: A non-empty `Config` instance.
	var config := Config.new()
	config.set_string(&"category", &"key", "value")

	# Given: A config writer writing to a file.
	writer = StdBinaryConfigWriter.new()
	writer.path = path
	add_child(writer)

	# Given: Non-empty config data is stored in that file.
	var err := writer.store_config(config).wait()
	assert_eq(err, OK)

	# Given: Invalid data is stored at the temporary file path.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	assert_not_null(file)
	file.store_buffer(var_to_bytes({&"category": {&"key": 1}}))  # Missing checksum.
	file.close()

	# Given: The config instance is reset.
	config = Config.new()

	# When: The config is loaded from disk.
	err = writer.load_config(config).wait()

	# Then: There's no error.
	assert_eq(err, OK)

	# Then: The config instance matches expectations
	assert_eq(config.get_string(&"category", &"key", ""), "value")


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
