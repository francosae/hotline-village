extends Node2D
## Dev tool: every emote kind in its bubble at game scale -> /tmp/hv_emotes_check.png

const NPCScript := preload("res://scripts/npc.gd")

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#bcd77a")
	bg.size = Vector2(400, 200)
	bg.position = Vector2(-40, -60)
	add_child(bg)
	var kinds: Array = Art.EMOTE_ICONS.keys()
	var ids := ["maple", "clucky", "juniper"]
	for i in kinds.size():
		var n := StaticBody2D.new()
		n.set_script(NPCScript)
		n.setup(ids[i % 3])
		n.position = Vector2(20 + (i % 6) * 50, 40 + (i / 6) * 60)
		add_child(n)
		var lbl := Label.new()
		lbl.text = kinds[i]
		lbl.add_theme_font_override("font", Art.world_font())
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", Color("#3d2a1c"))
		lbl.scale = Vector2(0.2, 0.2)
		lbl.position = n.position + Vector2(-14, 4)
		add_child(lbl)
	var cam := Camera2D.new()
	cam.zoom = Vector2(4, 4)
	cam.position = Vector2(145, 50)
	add_child(cam)
	await get_tree().process_frame
	for i in kinds.size():
		get_child(1 + i * 2).emote(kinds[i])
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/hv_emotes_check.png")
	print("[emotes] /tmp/hv_emotes_check.png")
	get_tree().quit()
