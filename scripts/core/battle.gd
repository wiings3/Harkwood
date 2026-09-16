class_name HarkBattle
extends RefCounted
## Pure fixed-step encounter simulation; presentation only consumes its events.
const DB = preload("res://scripts/core/catalog.gd")
var rng = RandomNumberGenerator.new()
var player: Dictionary = {}
var enemy: Dictionary = {}
var player_hp = 0.0
var enemy_hp = 0.0
var player_clock = 0.0
var enemy_clock = 0.0
var elapsed = 0.0
var potion_cooldown = 0.0
var status = "idle"
var enemy_id = ""
var stance = "balanced"

func begin(stats: Dictionary, id: String, hp: float = -1.0, battle_stance: String = "balanced") -> void:
	player = stats.duplicate(true)
	enemy = DB.ENEMIES[id].duplicate(true)
	enemy_id = id
	stance = battle_stance
	if stance == "fierce":
		player.attack *= 1.2
	elif stance == "guarded":
		player.attack *= 0.85
	player_hp = float(player.health) if hp < 0 else minf(hp, player.health)
	enemy_hp = enemy.health
	player_clock = 0.25
	enemy_clock = 0.8
	elapsed = 0.0
	potion_cooldown = 0.0
	status = "fighting"

func interval() -> float:
	return 1.25 / (1.0 + player.haste)

func tick(delta: float) -> Array:
	var events: Array = []
	if status != "fighting" or delta <= 0:
		return events
	elapsed += delta
	potion_cooldown = maxf(0.0, potion_cooldown - delta)
	player_clock -= delta
	enemy_clock -= delta
	if player_clock <= 0:
		player_clock += interval()
		var critical = rng.randf() < player.crit
		var damage = maxf(1, roundf(player.attack * 100.0 / (100.0 + enemy.armor) * (1.75 if critical else 1.0)))
		enemy_hp = maxf(0.0, enemy_hp - damage)
		player_hp = minf(player.health, player_hp + damage * player.leech)
		events.append({"type": "hit", "actor": "player", "damage": damage, "crit": critical})
		if enemy_hp <= 0:
			status = "won"
			events.append({"type": "won"})
			return events
	if enemy_clock <= 0:
		enemy_clock += enemy.interval
		var multiplier = 1.2 if stance == "fierce" else (0.75 if stance == "guarded" else 1.0)
		if enemy_id == "elder" and enemy_hp < enemy.health * 0.4:
			multiplier *= 1.25
		var damage = maxf(1, roundf(enemy.attack * 100.0 / (100.0 + player.armor) * multiplier))
		player_hp = maxf(0.0, player_hp - damage)
		events.append({"type": "hit", "actor": "enemy", "damage": damage, "crit": false})
		if player_hp <= 0:
			status = "lost"
			events.append({"type": "lost"})
	if elapsed > 180 and status == "fighting":
		status = "lost"
		events.append({"type": "lost"})
	return events

func heal() -> float:
	if status != "fighting" or potion_cooldown > 0 or player_hp >= player.health:
		return 0.0
	var restored = minf(player.health * 0.5, player.health - player_hp)
	player_hp += restored
	potion_cooldown = 6.0
	return restored
