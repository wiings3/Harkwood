extends "res://scripts/ui/world_view.gd"
## Node-scene variant: runtime world art stays behind editor-authored controls
## without using negative z-indices that can push it behind the HUD/backdrop.

func _ready() -> void:
	# Anything already in the scene is editor-authored UI and must remain on top.
	var authored_children: Array[Node] = get_children()
	for child in authored_children:
		if child is CanvasItem:
			child.z_index = 20

	# Let the original world view create the background, shade, actors and effects.
	super._ready()

	# Runtime world layers stay inside this World control, below the authored UI.
	if is_instance_valid(background):
		background.z_index = 0

	for child in get_children():
		if child in authored_children:
			continue
		if child is ColorRect and child != background:
			child.z_index = 0

	if is_instance_valid(hero):
		hero.z_index = 2
	if is_instance_valid(foe):
		foe.z_index = 2

	if has_meta("effects"):
		var effects: CanvasItem = get_meta("effects")
		if is_instance_valid(effects):
			effects.z_index = 3
