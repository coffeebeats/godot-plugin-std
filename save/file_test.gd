##
## Tests pertaining to the `StdSaveFile` class, covering the save data's dirty state
## after a write and requests made while the writer is busy.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## SaveFileTest is a save file writing to a test directory, which can fail or block its
## writes.
class SaveFileTest:
	extends StdSaveFile

	## block controls whether writes wait on `release` before proceeding.
	var block: bool = false

	## directory is the directory save files are written to.
	var directory: String = ""

	## entered is posted by the worker thread once a blocking write begins.
	var entered := Semaphore.new()

	## fail_writes is whether every write fails as a full disk would.
	var fail_writes: bool = false

	## release must be posted once per blocking write to let that write proceed.
	var release := Semaphore.new()

	func _exit_tree():
		# NOTE: Unblock any parked write so a failed test can't hang the teardown.
		release.post()
		super._exit_tree()

	func _config_write_bytes(config_path: String, data: PackedByteArray) -> Error:
		if block:
			entered.post()
			release.wait()

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


func test_store_save_data_success_leaves_data_clean(
	sync = use_parameters([true, false])
):
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# When: It is stored.
	var status: StdSaveFile.Status = await _store(data, sync)

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


func test_store_save_data_failure_leaves_data_dirty(
	sync = use_parameters([true, false])
):
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: Writes fail as a full disk would.
	_file.fail_writes = true

	# When: It is stored.
	var status: StdSaveFile.Status = await _store(data, sync)

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


func test_store_save_data_resolving_after_a_newer_store_leaves_data_clean(
	older_fails = use_parameters([false, true]),
):
	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: Writes fail as a full disk would, if the older store is to fail.
	_file.fail_writes = older_fails

	# Given: An asynchronous store started without awaiting it.
	_file.call(&"store_save_data", data)

	# Given: The worker resolved it, before the store resumes to read its result.
	_file.wait()

	# Given: Writes succeed again.
	_file.fail_writes = false

	# Given: Another change, made after the older store copied the data.
	data.item.value = 2

	# When: A newer store writes the data synchronously.
	var status := _file.store_save_data_sync(data)

	# When: The older store resumes on a later frame, reading its result.
	await wait_idle_frames(2)

	# Then: The newer write succeeded, and the data it wrote reads clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())

	# Then: A failed older store reported the full disk.
	if older_fails:
		assert_push_error("Disk full or write permission denied.")


func test_load_save_data_persisting_migrated_data_leaves_it_dirty_only_on_failure(
	fail_writes = use_parameters([false, true]),
):
	# Given: Save data stored at version 0.
	var stored := _create_dirty_data()
	_file.store_save_data_sync(stored)

	# Given: Save data at version 1, with a migration from version 0.
	var data := _create_dirty_data()
	data.version = 1
	var migration := MigrationTest.new()
	migration.version_from = 0
	data.migrations = [migration]

	# Given: Writes fail as a full disk would, if the persist is to fail.
	_file.fail_writes = fail_writes

	# When: It loads, migrating the saved data and persisting it.
	var status: StdSaveFile.Status = await _file.load_save_data(data)

	# Then: The load succeeded, and the data reads dirty only if the persist failed.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_eq(data.is_dirty(), fail_writes)


func test_load_save_data_during_a_write_returns_busy(
	sync = use_parameters([true, false]),
):
	# Given: A store is in flight, with the worker thread inside the write.
	var result_in_flight := _start_blocked_store()

	# Given: Save data holding a change.
	var data := _create_dirty_data()
	data.item.value = 12

	# Given: The save file's signals are watched.
	watch_signals(_file)

	# When: The save data is loaded while the store is in flight.
	var status: StdSaveFile.Status = await _load(data, sync)

	# When: The in-flight write is released.
	_finish_blocked_store(result_in_flight)

	# Then: The load was rejected as busy.
	assert_eq(status, StdSaveFile.STATUS_BUSY)
	assert_signal_emitted_with_parameters(
		_file, "save_loaded", [data, StdSaveFile.STATUS_BUSY]
	)

	# Then: The save data was left untouched.
	assert_eq(data.item.value, 12)


func test_store_save_data_during_a_write_returns_busy(
	sync = use_parameters([true, false]),
):
	# Given: A store is in flight, with the worker thread inside the write.
	var result_in_flight := _start_blocked_store()

	# Given: Save data with a change to save.
	var data := _create_dirty_data()

	# Given: The save file's signals are watched.
	watch_signals(_file)

	# When: The save data is stored while the store is in flight.
	var status: StdSaveFile.Status = await _store(data, sync)

	# When: The in-flight write is released.
	_finish_blocked_store(result_in_flight)

	# Then: The store was rejected as busy.
	assert_eq(status, StdSaveFile.STATUS_BUSY)
	assert_signal_emitted_with_parameters(
		_file, "save_stored", [data, StdSaveFile.STATUS_BUSY]
	)

	# Then: The unsaved data still reads dirty.
	assert_true(data.is_dirty())


func test_store_save_data_sync_after_a_busy_rejection_succeeds():
	# Given: A store is in flight, with the worker thread inside the write.
	var result_in_flight := _start_blocked_store()

	# Given: Save data holding a change.
	var data := _create_dirty_data()
	data.item.value = 12

	# Given: A store was rejected because the writer was busy.
	assert_eq(_file.store_save_data_sync(data), StdSaveFile.STATUS_BUSY)

	# Given: The in-flight write was released.
	_finish_blocked_store(result_in_flight)

	# When: The save data is stored again once the writer is idle.
	_file.block = false
	var status := _file.store_save_data_sync(data)

	# Then: The store succeeded and left the data clean.
	assert_eq(status, StdSaveFile.STATUS_OK)
	assert_false(data.is_dirty())

	# Then: The stored data can be loaded back.
	var got := _create_dirty_data()
	assert_eq(_file.load_save_data_sync(got), StdSaveFile.STATUS_OK)
	assert_eq(got.item.value, 12)


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


## _finish_blocked_store releases the write started by `_start_blocked_store` and waits
## for it to complete successfully.
func _finish_blocked_store(result: StdThreadWorkerResult) -> void:
	_file.release.post()
	assert_eq(result.wait(), OK)


## _load loads `data` through `load_save_data_sync` when `sync` is set, otherwise
## through `load_save_data`, and returns the status.
func _load(data: StdSaveData, sync: bool) -> StdSaveFile.Status:
	if sync:
		return _file.load_save_data_sync(data)

	return await _file.load_save_data(data)


## _start_blocked_store starts a store whose write blocks until released, returning
## once the worker thread is inside that write.
func _start_blocked_store() -> StdThreadWorkerResult:
	var config := Config.new()
	_create_dirty_data().store(config)

	_file.block = true
	var result := _file.store_config(config)
	_file.entered.wait()

	return result


## _store stores `data` through `store_save_data_sync` when `sync` is set, otherwise
## through `store_save_data`, and returns the status.
func _store(data: StdSaveData, sync: bool) -> StdSaveFile.Status:
	if sync:
		return _file.store_save_data_sync(data)

	return await _file.store_save_data(data)
