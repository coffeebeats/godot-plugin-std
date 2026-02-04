##
## Tests for StdRouterLoader.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_SCENE_PATH := "res://router/testdata/test_scene.tscn"
const _TEST_SCENE_PATH_2 := "res://router/testdata/test_scene_2.tscn"

var loader: StdRouterLoader = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_result_new_with_path_sets_path():
	# Given: A valid path.
	var path := "res://test/scene.tscn"

	# When: A Result is created with the path.
	var result := StdRouterLoader.Result.new_with_path(path)

	# Then: The path is set correctly.
	assert_eq(result.path, path)


func test_result_new_with_path_sets_initial_status():
	# Given: A valid path.
	var path := "res://test/scene.tscn"

	# When: A Result is created with the path.
	var result := StdRouterLoader.Result.new_with_path(path)

	# Then: The initial status is in progress.
	assert_eq(result.status, ResourceLoader.THREAD_LOAD_IN_PROGRESS)


func test_result_new_with_path_scene_is_null():
	# Given: A valid path.
	var path := "res://test/scene.tscn"

	# When: A Result is created with the path.
	var result := StdRouterLoader.Result.new_with_path(path)

	# Then: The scene is initially null.
	assert_null(result.scene)


func test_result_get_error_returns_ok_for_in_progress():
	# Given: A result with in-progress status.
	var result := StdRouterLoader.Result.new()
	result.status = ResourceLoader.THREAD_LOAD_IN_PROGRESS

	# When: get_error is called.
	var err := result.get_error()

	# Then: Returns OK (not an error state).
	assert_eq(err, OK)


func test_result_get_error_returns_ok_for_loaded():
	# Given: A result with loaded status.
	var result := StdRouterLoader.Result.new()
	result.status = ResourceLoader.THREAD_LOAD_LOADED

	# When: get_error is called.
	var err := result.get_error()

	# Then: Returns OK.
	assert_eq(err, OK)


func test_result_get_error_returns_invalid_for_invalid_resource():
	# Given: A result with invalid resource status.
	var result := StdRouterLoader.Result.new()
	result.status = ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

	# When: get_error is called.
	var err := result.get_error()

	# Then: Returns ERR_INVALID_PARAMETER.
	assert_eq(err, ERR_INVALID_PARAMETER)


func test_result_get_error_returns_failed_for_failed_status():
	# Given: A result with failed status.
	var result := StdRouterLoader.Result.new()
	result.status = ResourceLoader.THREAD_LOAD_FAILED

	# When: get_error is called.
	var err := result.get_error()

	# Then: Returns FAILED.
	assert_eq(err, FAILED)


func test_load_all_returns_empty_array_for_empty_dependencies():
	# Given: An empty dependencies resource.
	var deps := StdRouteDependencies.new()
	deps.resources = []

	# When: load_all is called.
	var results := loader.load_all(deps)

	# Then: An empty array is returned.
	assert_eq(results.size(), 0)


func test_load_all_returns_result_for_each_resource():
	# Given: Dependencies with multiple resources.
	var deps := StdRouteDependencies.new()
	deps.resources = [_TEST_SCENE_PATH, _TEST_SCENE_PATH_2]

	# When: load_all is called.
	var results := loader.load_all(deps)

	# Given: Signal emissions are monitored for all results.
	for result in results:
		watch_signals(result)

	# Then: Result count matches resource count.
	assert_eq(results.size(), 2)

	# Given: Results have not yet completed.
	assert_false(results[0].is_done())
	assert_false(results[1].is_done())

	# Then: Each result corresponds to the correct path.
	assert_eq(results[0].path, _TEST_SCENE_PATH)
	assert_eq(results[1].path, _TEST_SCENE_PATH_2)

	# When: All loads complete.
	for result in results:
		if not result.is_done():
			await wait_for_signal(result.done, 1.0)

	# Then: All results have signaled completion.
	assert_signal_emit_count(results[0], "done", 1)
	assert_signal_emit_count(results[1], "done", 1)

	# Then: All results have loaded status.
	assert_eq(results[0].status, ResourceLoader.THREAD_LOAD_LOADED)
	assert_eq(results[1].status, ResourceLoader.THREAD_LOAD_LOADED)

	# Then: All results have valid scenes.
	assert_true(results[0].scene is PackedScene)
	assert_true(results[1].scene is PackedScene)


func test_loader_process_callback_physics_enables_physics_process():
	# When: Process callback is set to physics.
	loader.process_callback = StdRouterLoader.ProcessCallback.PROCESS_CALLBACK_PHYSICS

	# Then: Physics process is enabled, regular process is disabled.
	assert_true(loader.is_physics_processing())
	assert_false(loader.is_processing())


func test_loader_process_callback_idle_enables_idle_process():
	# When: Process callback is set to idle.
	loader.process_callback = StdRouterLoader.ProcessCallback.PROCESS_CALLBACK_IDLE

	# Then: Regular process is enabled, physics process is disabled.
	assert_false(loader.is_physics_processing())
	assert_true(loader.is_processing())


func test_load_valid_scene_emits_done_signal():
	# Given: The test scene is loaded in the background.
	var result := loader.load(_TEST_SCENE_PATH)

	# Given: Signal emissions are monitored.
	watch_signals(result)

	# When: The load completes.
	await wait_for_signal(result.done, 1.0)

	# Then: The done signal was emitted exactly once.
	assert_signal_emit_count(result, "done", 1)


func test_load_valid_scene_sets_status_loaded():
	# Given: The test scene is loaded in the background.
	var result := loader.load(_TEST_SCENE_PATH)

	# When: The load completes.
	await wait_for_signal(result.done, 1.0)

	# Then: Status is LOADED.
	assert_eq(result.status, ResourceLoader.THREAD_LOAD_LOADED)


func test_load_valid_scene_returns_packed_scene():
	# Given: The test scene is loaded in the background.
	var result := loader.load(_TEST_SCENE_PATH)

	# When: The load completes.
	await wait_for_signal(result.done, 1.0)

	# Then: The scene is set.
	assert_not_null(result.scene)

	# Then: The scene is a valid 'PackedScene'.
	assert_true(result.scene is PackedScene)


func test_load_valid_scene_returns_ok_error():
	# Given: The test scene is loaded in the background.
	var result := loader.load(_TEST_SCENE_PATH)

	# When: The load completes.
	await wait_for_signal(result.done, 1.0)

	# Then: get_error returns OK.
	assert_eq(result.get_error(), OK)


func test_load_duplicate_path_returns_same_result():
	# When: The same path is loaded twice.
	var result1 := loader.load(_TEST_SCENE_PATH)
	var result2 := loader.load(_TEST_SCENE_PATH)

	# Then: The same result instance is returned (deduplication).
	assert_same(result1, result2)

	# Then: The load completes.
	await wait_for_signal(result1.done, 1.0)


func test_load_pending_request_enables_process_mode():
	# Given: A loader with processing disabled.
	assert_eq(loader.process_mode, Node.PROCESS_MODE_DISABLED)

	# When: A load is requested.
	var result := loader.load(_TEST_SCENE_PATH)

	# Then: Process mode is enabled.
	assert_eq(loader.process_mode, Node.PROCESS_MODE_ALWAYS)

	# Then: The load completes.
	await wait_for_signal(result.done, 1.0)


func test_load_completed_request_disables_process_mode():
	# Given: A pending load request.
	var result := loader.load(_TEST_SCENE_PATH)

	# When: The load completes.
	await wait_for_signal(result.done, 1.0)

	# Then: Process mode is disabled again.
	assert_eq(loader.process_mode, Node.PROCESS_MODE_DISABLED)


func test_load_cached_resource_returns_done_result():
	# Given: A resource that is already cached.
	var first_result := loader.load(_TEST_SCENE_PATH)
	await wait_for_signal(first_result.done, 1.0)
	assert_true(ResourceLoader.has_cached(_TEST_SCENE_PATH))

	# When: The same resource is loaded again.
	var result := loader.load(_TEST_SCENE_PATH)

	# Given: Signal emissions are monitored.
	watch_signals(result)

	# Then: The result is already finished loading.
	assert_eq(result.status, ResourceLoader.THREAD_LOAD_LOADED)

	# Then: Scene is available immediately.
	assert_true(result.scene is PackedScene)

	# Then: The done signal was not emitted.
	assert_signal_emit_count(result, "done", 0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	loader = autofree(StdRouterLoader.new())
	add_child(loader)


func after_each() -> void:
	# Clear the loaded resources from the cache.
	Resource.new().take_over_path(_TEST_SCENE_PATH)
	Resource.new().take_over_path(_TEST_SCENE_PATH_2)
