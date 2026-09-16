class_name HarkStateV2
extends "res://scripts/core/game_state.gd"
## Progression pass layered over the original save format so existing saves keep working.
const Catalog = preload("res://scripts/core/catalog.gd")

func new_game() -> void:
	super.new_game()
	_ensure_v2_fields()

func load_game() -> bool:
	var loaded := super.load_game()
	_ensure_v2_fields()
	return loaded

func _ensure_v2_fields() -> void:
	if not data.has("drop_pity"):
		data.drop_pity = 0
	if not data.has("online_gold_anchor"):
		data.online_gold_anchor = -1

func make_gear(id: String, quality: int = -1) -> Dictionary:
	if not Catalog.ITEMS.has(id):
		return {}
	if quality < 0:
		var roll := rng.randf()
		quality = 2 if roll < 0.10 else (1 if roll < 0.40 else 0)
	quality = clampi(quality, 0, 2)
	var affixes: Array = []
	if quality > 0:
		var first := rng.randi_range(0, Catalog.AFFIXES.size() - 1)
		affixes.append(first)
		if quality >= 2 and Catalog.AFFIXES.size() > 1:
			var second := rng.randi_range(0, Catalog.AFFIXES.size() - 1)
			while second == first:
				second = rng.randi_range(0, Catalog.AFFIXES.size() - 1)
			affixes.append(second)
	return {"uid": Crypto.new().generate_random_bytes(16).hex_encode(), "id": id,
		"quality": quality, "rank": 0, "affixes": affixes}

func gear_name(item: Dictionary) -> String:
	if not Catalog.ITEMS.has(item.get("id", "")):
		return "Unknown relic"
	var title: String = Catalog.ITEMS[item.id].name
	var quality := clampi(int(item.get("quality", 0)), 0, Catalog.RARITIES.size() - 1)
	if quality > 0:
		title = Catalog.RARITIES[quality] + " " + title
	var affixes: Array = item.get("affixes", [])
	if not affixes.is_empty():
		var first := clampi(int(affixes[0]), 0, Catalog.AFFIXES.size() - 1)
		title += " " + Catalog.AFFIXES[first].name
	if affixes.size() > 1:
		var second := clampi(int(affixes[1]), 0, Catalog.AFFIXES.size() - 1)
		var second_name: String = Catalog.AFFIXES[second].name
		if second_name.begins_with("of "):
			second_name = second_name.substr(3)
		title += " & " + second_name
	if int(item.get("rank", 0)) > 0:
		title += " +%d" % int(item.rank)
	return title

func reward_enemy(id: String) -> Dictionary:
	if not Catalog.ENEMIES.has(id):
		return {"gold": 0, "xp": 0, "materials": {}, "gear": ""}
	_ensure_v2_fields()
	var enemy: Dictionary = Catalog.ENEMIES[id]
	data.xp = int(data.xp) + int(enemy.xp)
	data.gold = int(data.gold) + int(enemy.gold)
	data.kills = int(data.kills) + 1
	grant_materials(enemy.loot)
	var result := {"gold": int(enemy.gold), "xp": int(enemy.xp), "materials": enemy.loot.duplicate(true), "gear": ""}
	var pity := int(data.drop_pity)
	var drop_chance := minf(0.52, 0.14 + pity * 0.04)
	var dropped := id == "elder" or rng.randf() < drop_chance
	if dropped:
		data.drop_pity = 0
		var pool: Array = []
		for item_id in Catalog.ITEMS:
			if int(Catalog.ITEMS[item_id].tier) == crafting_tier():
				pool.append(item_id)
		if not pool.is_empty():
			var forced_quality := 2 if id == "elder" else -1
			var item := make_gear(pool[rng.randi_range(0, pool.size() - 1)], forced_quality)
			data["stash" if data.bag.size() >= BAG_LIMIT else "bag"].append(item)
			result.gear = gear_name(item)
	else:
		data.drop_pity = mini(pity + 1, 10)
	return result

func _valid_item(item: Variant) -> bool:
	if not item is Dictionary or not item.get("uid") is String or item.uid.length() != 32:
		return false
	if not item.get("id") is String or not Catalog.ITEMS.has(item.id):
		return false
	for key in ["quality", "rank"]:
		if not (item.get(key) is float or item.get(key) is int):
			return false
		if item[key] != int(item[key]):
			return false
	if item.quality < 0 or item.quality > 2 or item.rank < 0 or item.rank > 3 or not item.get("affixes") is Array:
		return false
	for affix in item.affixes:
		if not (affix is float or affix is int) or affix < 0 or affix >= Catalog.AFFIXES.size() or affix != int(affix):
			return false
	return item.affixes.size() <= 2
