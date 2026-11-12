##
## Tests pertaining to the `StdSaveFile` class, covering the save data's dirty state
## after a write.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## SaveFileTest is a save file writing to a test directory, which can fail its writes.
class SaveFileTest:
	extends StdSaveFile

	## directory is the directory save files are written to.
	var directory: String = ""

	## fail_writes is whether every write fails as a full disk would.
	var fail_writes: bool = false

	func _config_write_bytes(config_path: String, data: PackedByteArray) -> Error:
		if fail_writes:
			return ERR_FILE_CANT_WRITE

		return super(config_path, data)

	func _get_save_directory() -> String:
		return directory


## SaveItemTest is a save data item holding one value.
class SaveItemTest:
	extends StdConfigItem

	@export var value: int = 0

	func _get_category() -> StringName:
		return &"item"


## MigrationTest is a schema migration which changes nothing.
class MigrationTest:
	extends StdConfigSchemaMigration

	func _migrate(_config: Config) -> void:
		pass


## SaveDataTest is save data holding one item.
class SaveDataTest:
	extends StdSaveData

	@export var item: SaveItemTest = null


# -- INITIALIZATION ------------------------------------------------------------------ #

## _directory is the case-specific test directory, removed after each test.
var _directory: String = ""

var _file: SaveFileTest = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_store_save_data_sync_success_leaves_data_clean():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# When: It is stored synchronously.
	var status := _file.store_save_data_sync(data)

	# Then: The write succeeded and left the data clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())


func test_store_save_data_success_leaves_data_clean():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# When: It is stored asynchronously.
	var status: StdSaveFile.Status = await _file.store_save_data(data)

	# Then: The write succeeded and left the data clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())


func test_store_save_data_keeps_a_change_made_while_writing():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: Another change queued for the end of the frame, while the write runs.
	data.item.set_deferred(&"value", 2)

	# When: It is stored asynchronously.
	var status: StdSaveFile.Status = await _file.store_save_data(data)

	# Then: The write succeeded, and the later change still reads dirty.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_true(data.is_dirty())


func test_store_save_data_keeps_a_mark_made_while_writing():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: A critical mark queued for the end of the frame, while the write runs.
	data.mark_critical.call_deferred()

	# When: It is stored asynchronously.
	await _file.store_save_data(data)

	# Then: The data is still critical.
	assert_true(data.is_critical())


func test_store_save_data_sync_failure_leaves_data_dirty():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: Writes fail as a full disk would.
	_file.fail_writes = true

	# When: It is stored synchronously.
	var status := _file.store_save_data_sync(data)

	# Then: The write failed and left the data dirty.
	assert_eq(status, StdSaveFile.STATUS_DISK_FULL)
	assert_true(data.is_dirty())
	assert_push_error("Disk full or write permission denied.")


func test_store_save_data_failure_leaves_data_dirty():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: Writes fail as a full disk would.
	_file.fail_writes = true

	# When: It is stored asynchronously.
	var status: StdSaveFile.Status = await _file.store_save_data(data)

	# Then: The write failed and left the data dirty.
	assert_eq(status, StdSaveFile.STATUS_DISK_FULL)
	assert_true(data.is_dirty())
	assert_push_error("Disk full or write permission denied.")


func test_store_save_data_reads_dirty_until_the_write_resolves():
	# Given: Save data with no change to save.
	var data := _create_dirty_data()
	data.clear_dirty()

	# Given: Writes fail as a full disk would.
	_file.fail_writes = true

	# Given: An asynchronous store started without awaiting it.
	_file.call(&"store_save_data", data)

	# When: The worker finishes, before the store resumes to read its result.
	_file.wait()

	# Then: The data reads dirty.
	assert_true(data.is_dirty())

	# Then: The store resolves on a later frame.
	await wait_idle_frames(2)
	assert_push_error("Disk full or write permission denied.")


func test_store_save_data_finishing_after_a_newer_store_leaves_data_clean():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: An asynchronous store started without awaiting it.
	_file.call(&"store_save_data", data)

	# Given: The worker finished it, before the store resumes to read its result.
	_file.wait()

	# Given: Another change, made after the older store copied the data.
	data.item.value = 2

	# When: A newer store writes the data synchronously.
	var status := _file.store_save_data_sync(data)

	# When: The older store resumes on a later frame.
	await wait_idle_frames(2)

	# Then: The newer write succeeded, and the data it wrote reads clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())


func test_store_save_data_failing_after_a_newer_store_leaves_data_clean():
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: Writes fail as a full disk would.
	_file.fail_writes = true

	# Given: An asynchronous store started without awaiting it.
	_file.call(&"store_save_data", data)

	# Given: The worker failed it, before the store resumes to read its result.
	_file.wait()

	# Given: Writes succeed again.
	_file.fail_writes = false

	# When: A newer store writes the data synchronously.
	var status := _file.store_save_data_sync(data)

	# When: The older store resumes on a later frame, reading its failure.
	await wait_idle_frames(2)

	# Then: The newer write succeeded, and the data it wrote reads clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())
	assert_push_error("Disk full or write permission denied.")


func test_load_save_data_persisting_migrated_data_leaves_it_clean():
	# Given: Save data stored at version 0.
	var stored := _create_dirty_data()
	_file.store_save_data_sync(stored)

	# Given: Save data at version 1, with a migration from version 0.
	var data := _create_dirty_data()
	data.version = 1
	var migration := MigrationTest.new()
	migration.version_from = 0
	data.migrations = [migration]

	# When: It loads, migrating and persisting the saved data.
	var status: StdSaveFile.Status = await _file.load_save_data(data)

	# Then: The load succeeded and left the data clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())


func test_load_save_data_failing_to_persist_migrated_data_leaves_it_dirty():
	# Given: Save data stored at version 0.
	var stored := _create_dirty_data()
	_file.store_save_data_sync(stored)

	# Given: Save data at version 1, with a migration from version 0.
	var data := _create_dirty_data()
	data.version = 1
	var migration := MigrationTest.new()
	migration.version_from = 0
	data.migrations = [migration]

	# Given: Writes fail as a full disk would.
	_file.fail_writes = true

	# When: It loads, migrating the saved data and failing to persist it.
	var status: StdSaveFile.Status = await _file.load_save_data(data)

	# Then: The load succeeded, and the unpersisted data reads dirty.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_true(data.is_dirty())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each():
	for filename in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))

	DirAccess.remove_absolute(_directory)


func before_each():
	_directory = "user://".path_join("test-%d" % randi())
	assert_eq(DirAccess.make_dir_recursive_absolute(_directory), OK)

	_file = SaveFileTest.new()
	_file.directory = _directory
	_file.path = "save://slot.dat"
	add_child_autoqfree(_file)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _create_dirty_data returns save data, with the summary a store requires, holding a
## change to save.
func _create_dirty_data() -> SaveDataTest:
	var data := SaveDataTest.new()
	data.summary = StdSaveSummary.new()
	data.item = SaveItemTest.new()
	data.reset()

	data.item.value = 1

	return data
