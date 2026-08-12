class_name InteractionHighlight
extends RefCounted

const OUTLINE_SHADER := preload("res://shaders/interaction_outline.gdshader")
const ORIGINAL_MATERIAL_META := &"interaction_highlight_original_material"


static func set_highlighted(target: CanvasItem, enabled: bool) -> void:
	if target == null:
		return
	if enabled:
		if target.has_meta(ORIGINAL_MATERIAL_META):
			return
		target.set_meta(ORIGINAL_MATERIAL_META, {"material": target.material})
		var outline_material := ShaderMaterial.new()
		outline_material.shader = OUTLINE_SHADER
		target.material = outline_material
		return
	if not target.has_meta(ORIGINAL_MATERIAL_META):
		return
	var original := target.get_meta(ORIGINAL_MATERIAL_META) as Dictionary
	target.material = original.get("material") as Material
	target.remove_meta(ORIGINAL_MATERIAL_META)


static func is_highlighted(target: CanvasItem) -> bool:
	return target != null and target.has_meta(ORIGINAL_MATERIAL_META)
