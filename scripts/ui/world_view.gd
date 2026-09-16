extends Control
## Local courtyard movement, map routes, ambient motes and battle actors.
const UI = preload("res://scripts/ui/palette.gd")
signal station_requested(id: String)
signal route_finished
var mode = "hub"
var background_path = "res://assets/art/hub.png"
var time = 0.0
var avatar = Vector2(474, 473)
var target = Vector2(474, 473)
var walking = false
var moving_to = ""
var hero: TextureRect
var foe: TextureRect
var stations = {"forge": Vector2(270, 338), "market": Vector2(699, 340),
	"stash": Vector2(167, 467), "map": Vector2(828, 421)}
var nodes = [Vector2(140, 495), Vector2(349, 391), Vector2(580, 252), Vector2(800, 162)]
var player_bump = 0.0
var enemy_bump = 0.0
var current_enemy_art = 2
var active = true
var route_index = 0
var route_progress = -1.0
var route_speed = 0.0
var route_from = Vector2.ZERO
var route_to = Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = TextureRect.new()
	background.texture = load(background_path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	if mode == "map":
		background.modulate = Color(0.63, 0.64, 0.53)
	else:
		hero = UI.icon(1 if mode == "hub" else 0, 1, true)
		add_child(hero)
		if mode == "battle":
			foe = UI.icon(current_enemy_art, 1, true)
			add_child(foe)
	var effects = Control.new()
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.draw.connect(func(): _draw_effects(effects))
	add_child(effects)
	set_meta("effects", effects)
	position_actors()

func _process(delta: float) -> void:
	time += delta
	player_bump = move_toward(player_bump, 0, delta * 160)
	enemy_bump = move_toward(enemy_bump, 0, delta * 160)
	if mode == "hub" and active:
		var direction = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if direction.length() > 0:
			target = avatar + direction.normalized() * 100
			moving_to = ""
		target.x = clampf(target.x, 140, 845)
		target.y = clampf(target.y, 335, 605)
		walking = avatar.distance_to(target) > 2
		avatar = avatar.move_toward(target, delta * 180)
		if not walking and moving_to != "":
			var destination = moving_to
			moving_to = ""
			station_requested.emit(destination)
	if mode == "map" and route_progress >= 0:
		route_progress += delta * route_speed
		if route_progress >= 1:
			route_progress = -1
			route_finished.emit()
	position_actors()
	if has_meta("effects"):
		get_meta("effects").queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if mode == "hub" and active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = event.position
		moving_to = ""
		accept_event()

func approach(station: String) -> void:
	if active:
		target = stations[station]
		moving_to = station

func interact() -> void:
	if not active:
		return
	for id in stations:
		if avatar.distance_to(stations[id]) < 105:
			station_requested.emit(id)
			return

func travel(to_index: int) -> void:
	route_from = nodes[0]
	route_to = nodes[to_index]
	route_index = to_index
	route_progress = 0
	route_speed = 0.7

func position_actors() -> void:
	if not is_instance_valid(hero):
		return
	if mode == "hub":
		hero.size = Vector2(78, 94)
		hero.position = avatar - Vector2(39, 88) + Vector2(0, sin(time * 12) * 2 if walking else sin(time * 2) * 0.6)
	else:
		hero.size = Vector2(235, 265)
		hero.position = Vector2(160 + player_bump, 271 + sin(time * 2.5) * 2)
		if is_instance_valid(foe):
			var height = 310 if current_enemy_art == 7 else 235
			foe.size = Vector2(300, height)
			foe.position = Vector2(563 - enemy_bump, 536 - height + sin(time * 2.2) * 3)

func enemy_art(index: int) -> void:
	current_enemy_art = index
	if is_instance_valid(foe):
		foe.texture = UI.atlas(index, true)
		foe.modulate = Color.WHITE
	position_actors()

func hit(who: String) -> void:
	var victim: TextureRect
	if who == "player":
		player_bump = 26
		victim = foe
	else:
		enemy_bump = 22
		victim = hero
	if is_instance_valid(victim):
		victim.modulate = Color(1.7, 0.7, 0.6)
		create_tween().tween_property(victim, "modulate", Color.WHITE, 0.22)

func _draw_effects(canvas: Control) -> void:
	for i in range(24):
		var x = fposmod(i * 137.4 + sin(time * 0.2 + i) * 25, size.x)
		var y = fposmod(i * 87.1 - time * (3 + i % 4), size.y)
		var alpha = (sin(time * 1.4 + i) + 1.1) * 0.17
		canvas.draw_circle(Vector2(x, y), 1.5, Color(0.95, 0.75, 0.4, alpha))
	if mode == "hub":
		canvas.draw_arc(avatar + Vector2(0, -2), 20, 0, TAU, 32, Color(0.85, 0.74, 0.49, 0.65), 1.3, true)
		if walking:
			canvas.draw_arc(target, 6, 0, TAU, 16, UI.GOLD, 1.2, true)
	elif mode == "map":
		for i in range(nodes.size() - 1):
			var a = nodes[i]
			var b = nodes[i + 1]
			for j in range(18):
				canvas.draw_circle(a.lerp(b, float(j) / 18), 2, Color(0.85, 0.75, 0.54, 0.75))
		for p in nodes:
			canvas.draw_circle(p, 27, UI.INK)
			canvas.draw_arc(p, 28, 0, TAU, 48, UI.GOLD, 1.5, true)
		if route_progress >= 0:
			var along = route_progress * route_index
			var segment = mini(int(along), route_index - 1)
			var marker = nodes[segment].lerp(nodes[segment + 1], along - segment)
			canvas.draw_circle(marker, 9, UI.GOLD)
			canvas.draw_arc(marker, 16, 0, TAU, 24, UI.PAPER, 2, true)
