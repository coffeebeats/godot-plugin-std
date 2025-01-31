##
## std/statistic/steam/achievement.gd
##
## StdAchievementSteam is a Steam-backed achievement.
##

class_name StdAchievementSteam
extends StdAchievement

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_unlocked() -> bool:
	var data := Steam.getAchievement(id)
	assert(data.get("ret", false), "failed to check achievement status")
	return data.get("achieved", false)


func _unlock() -> bool:
	return Steam.setAchievement(id)
