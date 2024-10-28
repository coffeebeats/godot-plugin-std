##
## Tests pertaining to the 'Config' class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ConfigWithFileSync := preload("file.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## path_test_dir is the path to the case-specific testing directory; this will be
## removed at the end of each test.
var path_test_dir: String

# -- TEST METHODS -------------------------------------------------------------------- #

func test_config_with_file_sync_create_new_file_is_successful():
    # Given: A test file path.
    var path := path_test_dir.path_join("test.dat")

    # When: A file-synced configuration item is created.
    var config := ConfigWithFileSync.sync_to_file(path)

    # Then: The 'ConfigWithFileSync' instance is successfully created.
    assert_not_null(config)

    # Then: The settings file exists.
    assert_true(FileAccess.file_exists(path))

func test_config_with_file_sync_create_new_nested_file_is_successful():
    # Given: A test file path that's nested in a non-existent directory.
    var path := path_test_dir.path_join("directory/does/not/exist/test.dat")

    # When: A file-synced configuration item is created.
    var config := ConfigWithFileSync.sync_to_file(path)

    # Then: The 'ConfigWithFileSync' instance is successfully created.
    assert_not_null(config)

    # Then: The settings file exists.
    assert_true(FileAccess.file_exists(path))

func test_config_with_file_sync_set_value_updates_file():
    # Given: A test file path.
    var path := path_test_dir.path_join("test.dat")

    # Given: A file-synced configuration item is created.
    var config := ConfigWithFileSync.sync_to_file(path)

    # Given: Signal emissions are monitored.
    watch_signals(config)

    # When: A float value is set.
    config.set_float("category", "key", 1.0)

    # Then: The value is present.
    assert_true(config.has_float("category", "key"))
    assert_eq(config.get_float("category", "key", 0.0), 1.0)

    # Then: The 'changed' signal was emitted.
    assert_signal_emit_count(config, "changed", 1)
    assert_signal_emitted_with_parameters(config, "changed", ["category", "key"])

    # Given: The 'ConfigWithFileSync' is closed.
    config.close()

    # Then: The file contents match expectations.
    var bytes := FileAccess.get_file_as_bytes(path)
    assert_gt(bytes.size(), 0)

    var data: Dictionary = bytes_to_var(bytes)
    assert_not_null(data)

    var category: Dictionary = data.get("category")
    assert_not_null(category)

    # Then: The stored value matches expectations.
    assert_eq(category.get("key"), 1.0)

func test_config_with_file_sync_loads_data_from_file():
    # Given: A test file path.
    var path := path_test_dir.path_join("test.dat")

    # Given: The settings file is created.
    var file := FileAccess.open(path, FileAccess.WRITE)
    assert_not_null(file)

    # Given: Configuration data with one value.
    var want := {"category": {"key": 1.0}}

    # Given: The configuration data is written to the file.
    file.store_buffer(var_to_bytes(want))
    file.close()

    # Given: A file-synced configuration item is created.
    var config := ConfigWithFileSync.sync_to_file(path)

    # Given: Signal emissions are monitored.
    watch_signals(config)

    # When: A float value, the same as already exists, is set.
    config.set_float("category", "key", 1.0)

    # Then: The value is present.
    assert_true(config.has_float("category", "key"))
    assert_eq(config.get_float("category", "key", 0.0), 1.0)

    # Then: The 'changed' signal was *not* emitted.
    assert_signal_emit_count(config, "changed", 0)

    # Given: The 'ConfigWithFileSync' is closed.
    config.close()

    # Then: The file contents match expectations.
    var bytes := FileAccess.get_file_as_bytes(path)
    assert_gt(bytes.size(), 0)

    var data: Dictionary = bytes_to_var(bytes)
    assert_not_null(data)

    var category: Dictionary = data.get("category")
    assert_not_null(category)

    # Then: The stored value matches expectations.
    assert_eq(category.get("key"), 1.0)


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
    assert_eq(DirAccess.make_dir_absolute(path_test_dir), OK)

func before_all():
    # NOTE: Hide unactionable errors when using object doubles.
    ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
