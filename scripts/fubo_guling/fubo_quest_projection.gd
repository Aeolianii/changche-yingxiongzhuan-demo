class_name FuboQuestProjection
extends RefCounted


static func current_step_title(progress_stage: int, keeper_intro_completed: bool) -> String:
	if progress_stage >= 4:
		return "伏波古岭巡视完成"
	if not keeper_intro_completed:
		return "寻找守岭人"
	match clampi(progress_stage, 0, 4):
		0, 1:
			return "码头摆钩钓鱼"
		2:
			return "完成古校场鼓令"
		3:
			return "登岭眺望南海"
	return "伏波古岭巡视完成"
