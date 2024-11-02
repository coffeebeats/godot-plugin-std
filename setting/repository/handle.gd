##
## std/setting/repository/handle.gd
##
## SettingsRepositoryHandle is a resource that uniquely identifies a
## 'SettingsRepository' scope. Note that the object ID of this resource is used to
## check for equality, not the name.
##

class_name SettingsRepositoryHandle
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## debug_name is a debug label to apply to the repository; it serves no purpose within a
## released application.
@export var debug_name: String = ""
