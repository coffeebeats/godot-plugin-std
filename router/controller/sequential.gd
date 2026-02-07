##
## router/controller/sequential.gd
##
## StdRouterControllerSequential implements sequential scene transitions: exit transition
## runs first, then the old scene is unmounted, new scene is mounted, enter transition
## runs, and finally navigation completes.
##
## This is the default controller used by StdRouter when no custom controller is provided.
##

class_name StdRouterControllerSequential
extends StdRouterController

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start() -> void:
	# Step 1: Start exit transition (or skip to step 2).
	if not _run_exit_transition():
		_after_exit()


func _on_exit_transition_completed() -> void:
	_after_exit()


func _on_enter_transition_completed() -> void:
	_done()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _after_exit handles the steps after exit transition completes.
func _after_exit() -> void:
	# Step 2: Unmount old scene.
	_unmount_scene()

	# Step 3: Mount new scene.
	_mount_scene()

	# Step 4: Start enter transition (or skip to done).
	if not _run_enter_transition():
		_done()
