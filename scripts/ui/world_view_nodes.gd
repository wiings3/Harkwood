extends "res://scripts/ui/world_view.gd"
## Node-scene variant: runtime art/effects stay behind editor-authored controls.

func _ready() -> void:
	super._ready()
	if is_instance_valid(background):
		background.z_index = -100
	for child in get_children():
		if child is ColorRect and child != background:
			child.z_index = -90
	if has_meta("effects"):
		var effects = get_meta("effects")
		if is_instance_valid(effects):
			effects.z_index = -70
	if is_instance_valid(hero):
		hero.z_index = -20
	if is_instance_valid(foe):
		foe.z_index = -20
