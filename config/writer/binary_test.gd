##
## Tests pertaining to the `StdConfigWriterBinary` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## path_test_dir is the path to the case-specific testing directory; this will be
## removed at the end of each test.
var path_test_dir: String

var writer: StdConfigWriterBinary = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_writer_load_config_reads_existing_file_data():
	# Given: A config writer writing to a file.
	writer.path = path_test_dir.path_join("test.dat")

	# Given: A non-empty Config instance.
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
	# Given: A non-empty Config instance.
	var config := Config.new()
	config.set_string(&"category", &"key", "value")

	# Given: A config writer writing to a tmp file.
	var path := path_test_dir.path_join("test.dat")
	writer.path = path + ".tmp"

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
	# Given: A non-empty Config instance.
	var config := Config.new()
	config.set_string(&"category", &"key", "value")

	# Given: A config writer writing to a file.
	var path := path_test_dir.path_join("test.dat")
	writer.path = path

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


func test_serialize_produces_deterministic_output():
	# Given: Two Configs with same data in different insertion order.
	var config_a := Config.new()
	config_a.set_int(&"alpha", &"x", 1)
	config_a.set_int(&"alpha", &"y", 2)
	config_a.set_int(&"beta", &"a", 10)

	var config_b := Config.new()
	config_b.set_int(&"beta", &"a", 10)
	config_b.set_int(&"alpha", &"y", 2)
	config_b.set_int(&"alpha", &"x", 1)

	# When: Both are serialized to bytes.
	var bytes_a := writer.to_bytes(config_a)
	var bytes_b := writer.to_bytes(config_b)

	# Then: The output is identical.
	assert_eq(
		bytes_a, bytes_b, "Same data in different order should produce identical bytes"
	)


func test_to_bytes_from_bytes_round_trip():
	# Given: A Config with various types.
	var config := Config.new()
	config.set_int(&"player", &"health", 100)
	config.set_string(&"player", &"name", "Hero")
	config.set_bool(&"settings", &"fullscreen", true)

	# When: Serialized and then deserialized.
	var bytes := writer.to_bytes(config)
	var restored := writer.from_bytes(bytes)

	# Then: Values match.
	assert_not_null(restored, "from_bytes should return a valid Config")
	assert_eq(restored.get_int(&"player", &"health", 0), 100)
	assert_eq(restored.get_string(&"player", &"name", ""), "Hero")
	assert_eq(restored.get_bool(&"settings", &"fullscreen", false), true)


func test_from_bytes_rejects_invalid_checksum():
	# Given: A valid serialized Config.
	var config := Config.new()
	config.set_int(&"test", &"value", 42)
	var bytes := writer.to_bytes(config)

	# When: A byte in the payload is flipped.
	bytes[bytes.size() - 1] = bytes[bytes.size() - 1] ^ 0xFF

	# Then: from_bytes returns null.
	var result := writer.from_bytes(bytes)
	assert_null(result, "from_bytes should return null for invalid checksum")


func test_binary_falls_back_to_backup_on_corrupted_main():
	# Given: A binary writer with backup_count = 1.
	var path := path_test_dir.path_join("save.dat")
	writer.path = path
	writer.backup_count = 1

	# Given: First store with valid data.
	var config_a := Config.new()
	config_a.set_int(&"game", &"score", 100)
	var err := writer.store_config(config_a).wait()
	assert_eq(err, OK, "First store should succeed")

	# Given: Second store with new data (first data is now in .bak).
	var config_b := Config.new()
	config_b.set_int(&"game", &"score", 200)
	err = writer.store_config(config_b).wait()
	assert_eq(err, OK, "Second store should succeed")

	# Given: The main file is corrupted.
	var abs_path := writer.FilePath.make_project_path_absolute(path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to open main file for corruption")
	file.store_buffer(PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]))
	file.close()

	# When: The config is loaded from disk.
	var config_loaded := Config.new()
	err = writer.load_config(config_loaded).wait()

	# Then: Load succeeds via backup fallback.
	assert_eq(err, OK, "Load should succeed via backup fallback")

	# Then: The recovered data matches the first store.
	assert_eq(
		config_loaded.get_int(&"game", &"score", 0),
		100,
		"Should recover backup data (first store)",
	)

	# Then: The main file was restored from the backup.
	assert_true(
		FileAccess.file_exists(abs_path),
		"Main file should be restored after backup recovery",
	)
	var restored := writer.from_bytes(FileAccess.get_file_as_bytes(abs_path))
	assert_not_null(
		restored,
		"Restored main file should contain valid data",
	)
	assert_eq(
		restored.get_int(&"game", &"score", 0),
		100,
		"Restored main file should contain backup data",
	)


func test_binary_falls_back_to_backup_when_main_file_missing():
	# Given: A binary writer with backup_count = 1.
	var path := path_test_dir.path_join("save.dat")
	writer.path = path
	writer.backup_count = 1

	# Given: First store with valid data.
	var config_a := Config.new()
	config_a.set_int(&"game", &"score", 100)
	var err := writer.store_config(config_a).wait()
	assert_eq(err, OK, "First store should succeed")

	# Given: Second store with new data (first data is now in .bak).
	var config_b := Config.new()
	config_b.set_int(&"game", &"score", 200)
	err = writer.store_config(config_b).wait()
	assert_eq(err, OK, "Second store should succeed")

	# Given: The main file is deleted.
	var abs_path := writer.FilePath.make_project_path_absolute(path)
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
		config_loaded.get_int(&"game", &"score", 0),
		100,
		"Should recover backup data (first store)",
	)

	# Then: The main file was restored from the backup.
	assert_true(
		FileAccess.file_exists(abs_path),
		"Main file should be restored after backup recovery",
	)
	var restored := writer.from_bytes(FileAccess.get_file_as_bytes(abs_path))
	assert_not_null(
		restored,
		"Restored main file should contain valid data",
	)
	assert_eq(
		restored.get_int(&"game", &"score", 0),
		100,
		"Restored main file should contain backup data",
	)


func test_from_bytes_rejects_invalid_compression_mode():
	# Given: A valid serialized Config.
	var config := Config.new()
	config.set_int(&"test", &"value", 42)
	var bytes := writer.to_bytes(config)

	# When: The compression mode byte is set to an invalid value.
	bytes[0] = 255

	# Then: from_bytes returns null.
	var result := writer.from_bytes(bytes)
	assert_null(
		result,
		"from_bytes should return null for invalid compression mode",
	)


func test_to_bytes_from_bytes_round_trip_all_compression_modes(
	mode = use_parameters(StdConfigWriterBinary.CompressionMode.values()),
):
	# Given: A Config with data.
	var config := Config.new()
	config.set_string(&"data", &"content", "Hello, compressed world!")
	config.set_int(&"data", &"count", 999)

	# When: Serialized and deserialized with the given mode.
	var bytes := writer.to_bytes(config, mode)
	var restored := writer.from_bytes(bytes)

	# Then: The mode byte matches the requested mode.
	assert_eq(bytes[0], mode)

	# Then: Data round-trips correctly.
	assert_not_null(restored)
	assert_eq(
		restored.get_string(&"data", &"content", ""),
		"Hello, compressed world!",
	)
	assert_eq(restored.get_int(&"data", &"count", 0), 999)


func test_from_bytes_rejects_truncated_input():
	# Given: Empty input.
	var empty := PackedByteArray()

	# Then: from_bytes returns null.
	assert_null(
		writer.from_bytes(empty),
		"from_bytes should return null for empty input",
	)

	# Given: A 10-byte array (minimum valid is 29: 1 mode + 8 size + 16 checksum + 4
	# variant).
	var short := PackedByteArray()
	short.resize(10)

	# Then: from_bytes returns null.
	assert_null(
		writer.from_bytes(short),
		"from_bytes should return null for truncated input",
	)


func test_from_bytes_rejects_mismatched_uncompressed_size():
	# Given: A valid uncompressed serialized Config.
	var config := Config.new()
	config.set_int(&"test", &"value", 42)
	var bytes := writer.to_bytes(config)

	# When: The uncompressed size field is tampered with.
	(
		bytes
		. encode_s64(
			StdConfigWriterBinary.COMPRESSION_MODE_BYTE_LENGTH,
			999,
		)
	)

	# Then: from_bytes returns null.
	assert_null(
		writer.from_bytes(bytes),
		"from_bytes should reject mismatched size",
	)


func test_from_bytes_rejects_non_dictionary_variant():
	# Given: Bytes encoding an Array (not a Dictionary).
	var payload := var_to_bytes([1, 2, 3])

	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(payload)
	var checksum := ctx.finish()

	var size_bytes := PackedByteArray()
	size_bytes.resize(StdConfigWriterBinary.UNCOMPRESSED_SIZE_BYTE_LENGTH)
	size_bytes.encode_s64(0, payload.size())

	var bytes := PackedByteArray()
	bytes.append(StdConfigWriterBinary.CompressionMode.NONE)
	bytes.append_array(size_bytes)
	bytes.append_array(checksum)
	bytes.append_array(payload)

	# Then: from_bytes returns null.
	assert_null(
		writer.from_bytes(bytes),
		"from_bytes should reject non-Dictionary data",
	)


func test_empty_config_round_trip():
	# Given: An empty Config.
	var config := Config.new()

	# When: Serialized and deserialized.
	var bytes := writer.to_bytes(config)
	var restored := writer.from_bytes(bytes)

	# Then: The restored config is valid with empty data.
	assert_not_null(restored, "from_bytes should return a valid Config")
	assert_eq(restored._data, {}, "Restored config should have empty data")


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

	writer = StdConfigWriterBinary.new()
	writer.path = path_test_dir.path_join("default.dat")
	add_child_autoqfree(writer)


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
