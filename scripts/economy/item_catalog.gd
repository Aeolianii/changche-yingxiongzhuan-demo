class_name ItemCatalog
extends RefCounted

const ITEMS := {
	"wood": {"name": "木材", "category": "material", "buy_price": 12, "sell_price": 6, "source": "初始库存、海上漂流箱、战斗结算、商港购买"},
	"ironstone": {"name": "铁石", "category": "material", "buy_price": 18, "sell_price": 9, "source": "初始库存、海上漂流箱、战斗结算、商港购买"},
	"yellow_croaker": {"name": "黄花鱼", "category": "specialty", "buy_price": 0, "sell_price": 18, "source": "伏波古岭钓鱼"},
	"grouper": {"name": "大石斑", "category": "specialty", "buy_price": 0, "sell_price": 45, "source": "伏波古岭钓鱼"},
	"green_crab": {"name": "青蟹", "category": "specialty", "buy_price": 0, "sell_price": 30, "source": "伏波古岭钓鱼"},
	"old_boot": {"name": "旧靴子", "category": "misc", "buy_price": 0, "sell_price": 2, "source": "伏波古岭钓鱼"},
	"longjing_tea": {"name": "龙井茶", "category": "cargo", "buy_price": 0, "sell_price": 160, "source": "海上龙井茶商"},
	"private_salt": {"name": "私盐", "category": "cargo", "buy_price": 0, "sell_price": 120, "source": "海上私盐商"},
}

const SHIPS := {
	"patrol_boat": {"name": "巡哨快船", "blueprint_price": 300, "pay": 240, "wood": 36, "ironstone": 14, "max_hp": 60},
	"cannon_warship": {"name": "火炮战船", "blueprint_price": 500, "pay": 340, "wood": 52, "ironstone": 30, "max_hp": 72},
	"escort_junk": {"name": "护航广船", "blueprint_price": 600, "pay": 380, "wood": 70, "ironstone": 22, "max_hp": 88},
}
const FISHING_REWARDS := {"small_fish": "yellow_croaker", "big_fish": "grouper", "crab": "green_crab", "boot": "old_boot"}


static func item_ids() -> Array:
	return ITEMS.keys()


static func item(item_id: String) -> Dictionary:
	return (ITEMS.get(item_id, {}) as Dictionary).duplicate(true)


static func ship(ship_type_id: String) -> Dictionary:
	return (SHIPS.get(ship_type_id, {}) as Dictionary).duplicate(true)


static func fishing_reward_id(catch_kind: String) -> String:
	return str(FISHING_REWARDS.get(catch_kind, ""))
