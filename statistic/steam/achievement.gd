##
## std/statistic/steam/achievement.gd
##
## StdAchievementSteam is a Steam-backed achievement.
##

class_name StdAchievementSteam
extends StdAchievement

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_unlocked() -> bool:
	return Steam.getAchievement(id)


func _unlock() -> bool:
	return Steam.setAchievement(id)
