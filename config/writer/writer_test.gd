##
## Tests pertaining to the `StdConfigWriter` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")
const FilePath := preload("../../file/path.gd")

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


func test_config_writer_load_config_fails_if_directory_is_missing():
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

	# Then: The error matches expectations.
	assert_eq(err, ERR_FILE_NOT_FOUND)


func test_config_writer_load_config_fails_if_file_is_missing():
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

	# Then: The error matches expectations.
	assert_eq(err, ERR_FILE_NOT_FOUND)


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


func test_config_writer_store_config_succeeds_when_nested_file_does_not_exist():
	# Given: A test file path.
	var path := path_test_dir.path_join("nested/test.dat")

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


func test_creates_backup_on_write():
	# Given: A test file path.
	var path := path_test_dir.path_join("config.dat")

	# Given: A config writer with backup_count = 1.
	writer = StdConfigWriterTest.new()
	writer.path = path
	writer.backup_count = 1
	add_child(writer)

	# Given: First store.
	var config_a := Config.new()
	config_a.set_int(&"data", &"value", 10)
	var err := writer.store_config(config_a).wait()
	assert_eq(err, OK, "First store should succeed")

	# When: Second store — first data should be backed up.
	var config_b := Config.new()
	config_b.set_int(&"data", &"value", 20)
	err = writer.store_config(config_b).wait()
	assert_eq(err, OK, "Second store should succeed")

	# Then: .bak file exists.
	var bak_path := FilePath.make_project_path_absolute(path + ".bak")
	assert_true(
		FileAccess.file_exists(bak_path),
		".bak file should exist after second write",
	)


func test_rotates_backups():
	# Given: A test file path.
	var path := path_test_dir.path_join("config.dat")

	# Given: A config writer with backup_count = 2.
	writer = StdConfigWriterTest.new()
	writer.path = path
	writer.backup_count = 2
	add_child(writer)

	# When: Three stores are performed.
	for i in range(3):
		var config := Config.new()
		config.set_int(&"data", &"value", i)
		var err := writer.store_config(config).wait()
		assert_eq(err, OK, "Store %d should succeed" % i)

	# Then: .bak and .bak2 exist.
	var bak_path := FilePath.make_project_path_absolute(path + ".bak")
	var bak2_path := FilePath.make_project_path_absolute(path + ".bak2")
	assert_true(
		FileAccess.file_exists(bak_path),
		".bak should exist after three writes",
	)
	assert_true(
		FileAccess.file_exists(bak2_path),
		".bak2 should exist after three writes",
	)


func test_falls_back_to_backup_on_corrupted_main():
	# Given: A test file path.
	var path := path_test_dir.path_join("config.dat")

	# Given: A config writer with backup_count = 1.
	writer = StdConfigWriterTest.new()
	writer.path = path
	writer.backup_count = 1
	add_child(writer)

	# Given: First store with valid data.
	var config_a := Config.new()
	config_a.set_int(&"data", &"value", 42)
	var err := writer.store_config(config_a).wait()
	assert_eq(err, OK, "First store should succeed")

	# Given: Second store with new data.
	var config_b := Config.new()
	config_b.set_int(&"data", &"value", 99)
	err = writer.store_config(config_b).wait()
	assert_eq(err, OK, "Second store should succeed")

	# Given: The main file is corrupted.
	var abs_path := FilePath.make_project_path_absolute(path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to open main file for corruption")
	file.store_buffer(PackedByteArray([0xFF, 0xFE, 0xFD, 0xFC]))
	file.close()

	# When: The config is loaded from disk.
	var config_loaded := Config.new()
	err = writer.load_config(config_loaded).wait()

	# Then: Load succeeds via backup fallback.
	assert_eq(err, OK, "Load should succeed via backup fallback")

	# Then: Godot's bytes_to_var rejected the corrupt variant header.
	assert_engine_error("Variant::VARIANT_MAX")

	# Then: The recovered data matches the first store.
	assert_eq(
		config_loaded.get_int(&"data", &"value", 0),
		42,
		"Should recover first store's data from backup",
	)

	# Then: The main file was restored from the backup.
	assert_true(
		FileAccess.file_exists(abs_path),
		"Main file should be restored after backup recovery",
	)
	var restored: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(abs_path))
	assert_eq(
		restored[&"data"][&"value"],
		42,
		"Restored main file should contain backup data",
	)


func test_falls_back_to_backup_when_main_file_missing():
	# Given: A test file path.
	var path := path_test_dir.path_join("config.dat")

	# Given: A config writer with backup_count = 1.
	writer = StdConfigWriterTest.new()
	writer.path = path
	writer.backup_count = 1
	add_child(writer)

	# Given: First store with valid data.
	var config_a := Config.new()
	config_a.set_int(&"data", &"value", 42)
	var err := writer.store_config(config_a).wait()
	assert_eq(err, OK, "First store should succeed")

	# Given: Second store with new data (first data is now in .bak).
	var config_b := Config.new()
	config_b.set_int(&"data", &"value", 99)
	err = writer.store_config(config_b).wait()
	assert_eq(err, OK, "Second store should succeed")

	# Given: The main file is deleted.
	var abs_path := FilePath.make_project_path_absolute(path)
	DirAccess.remove_absolute(abs_path)
	assert_false(
		FileAccess.file_exists(abs_path),
		"Main file should be deleted",
	)

	# When: The config is loaded from disk.
	var config_loaded := Config.new()
	err = writer.load_config(config_loaded).wait()

	# Then: Load succeeds via backup fallback.
	assert_eq(err, OK, "Load should succeed via backup fallback")

	# Then: The recovered data matches the first store (now in .bak).
	assert_eq(
		config_loaded.get_int(&"data", &"value", 0),
		42,
		"Should recover first store's data from backup",
	)

	# Then: The main file was restored from the backup.
	assert_true(
		FileAccess.file_exists(abs_path),
		"Main file should be restored after backup recovery",
	)
	var restored: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(abs_path))
	assert_eq(
		restored[&"data"][&"value"],
		42,
		"Restored main file should contain backup data",
	)


func test_rotates_backups_and_evicts_oldest():
	# Given: A test file path.
	var path := path_test_dir.path_join("config.dat")

	# Given: A config writer with backup_count = 3.
	writer = StdConfigWriterTest.new()
	writer.path = path
	writer.backup_count = 3
	add_child(writer)

	# When: 5 stores are performed with values 0..4.
	for i in range(5):
		var config := Config.new()
		config.set_int(&"data", &"value", i)
		var err := writer.store_config(config).wait()
		assert_eq(err, OK, "Store %d should succeed" % i)

	# Then: .bak, .bak2, .bak3 exist; .bak4 does not.
	var abs_path := FilePath.make_project_path_absolute(path)
	var bak_path := FilePath.make_project_path_absolute(path + ".bak")
	var bak2_path := FilePath.make_project_path_absolute(path + ".bak2")
	var bak3_path := FilePath.make_project_path_absolute(path + ".bak3")
	var bak4_path := FilePath.make_project_path_absolute(path + ".bak4")

	assert_true(FileAccess.file_exists(bak_path), ".bak should exist")
	assert_true(FileAccess.file_exists(bak2_path), ".bak2 should exist")
	assert_true(FileAccess.file_exists(bak3_path), ".bak3 should exist")
	assert_false(FileAccess.file_exists(bak4_path), ".bak4 should not exist")

	# Then: Verify contents — main=4, .bak=3, .bak2=2, .bak3=1.
	var main_data: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(abs_path))
	assert_eq(main_data[&"data"][&"value"], 4, "Main should contain value 4")

	var bak_data: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(bak_path))
	assert_eq(bak_data[&"data"][&"value"], 3, ".bak should contain value 3")

	var bak2_data: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(bak2_path))
	assert_eq(bak2_data[&"data"][&"value"], 2, ".bak2 should contain value 2")

	var bak3_data: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(bak3_path))
	assert_eq(bak3_data[&"data"][&"value"], 1, ".bak3 should contain value 1")


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
