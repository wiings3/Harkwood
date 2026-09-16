extends Control
## Keeps the hand-authored 1440x900 interface usable at common desktop resolutions.
## The game surface is uniformly scaled and centered; the outer root fills the window.
const DESIGN_SIZE := Vector2(1440.0, 900.0)
@onready var game_surface: Control = $Game

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout.call_deferred()

func _apply_layout() -> void:
	if not is_instance_valid(game_surface):
		return
	var available := get_viewport_rect().size
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var factor := minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	factor = maxf(factor, 0.1)
	game_surface.size = DESIGN_SIZE
	game_surface.pivot_offset = Vector2.ZERO
	game_surface.scale = Vector2(factor, factor)
	game_surface.position = ((available - DESIGN_SIZE * factor) * 0.5).round()
