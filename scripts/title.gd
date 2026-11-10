extends Control

var logo: Label
var press: Label

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment(){
	vec2 uv = UV;
	vec3 a = vec3(0.62, 0.86, 0.66);
	vec3 b = vec3(0.98, 0.92, 0.72);
	float w = sin(uv.x * 10.0 + TIME * 0.6) * 0.03 + sin(uv.x * 23.0 - TIME) * 0.01;
	float band = step(0.72 + w, uv.y);
	vec3 sky = mix(vec3(0.68, 0.88, 0.98), vec3(1.0, 0.93, 0.83), uv.y);
	vec3 col = mix(sky, mix(a, a * 0.9, step(0.5, fract((uv.x + uv.y) * 12.0 + TIME * 0.05))), band);
	vec2 g = fract(uv * vec2(16.0, 9.0) + vec2(TIME * 0.02, 0.0)) - 0.5;
	float dots = smoothstep(0.08, 0.06, length(g)) * (1.0 - band) * 0.25;
	COLOR = vec4(col + dots, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	add_child(bg)
	# drifting petals
	var p := CPUParticles2D.new()
	p.amount = 50
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.position = Vector2(640, -20)
	p.direction = Vector2(-0.3, 1)
	p.spread = 15
	p.gravity = Vector2(0, 10)
	p.initial_velocity_min = 30
	p.initial_velocity_max = 60
	p.angular_velocity_min = -120
	p.angular_velocity_max = 120
	p.scale_amount_min = 4
	p.scale_amount_max = 8
	p.color = Color("#ffc4d6")
	add_child(p)
	# characters
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(440, 470)
	row.size = Vector2(400, 160)
	for id in ["maple", "juniper", "clucky"]:
		var tr := TextureRect.new()
		tr.texture = Art.npc_portrait(id)
		tr.modulate = Art.SHEETS[id]["modulate"]
		tr.flip_h = id == "maple"
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(130, 130)
		tr.pivot_offset = Vector2(65, 130)
		row.add_child(tr)
		var t := tr.create_tween().set_loops()
		t.tween_interval(randf() * 0.6)
		t.tween_property(tr, "scale", Vector2(1.06, 0.94), 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(tr, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	add_child(row)
	logo = UiKit.label("Hotline Village", 112, Color("#fff8e7"))
	logo.add_theme_color_override("font_outline_color", Color("#6b4a32"))
	logo.add_theme_constant_override("outline_size", 28)
	logo.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.1, 0.35))
	logo.add_theme_constant_override("shadow_offset_y", 10)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(0, 110)
	logo.size = Vector2(1280, 140)
	logo.anchor_left = 0
	logo.anchor_right = 1
	logo.offset_left = 0
	logo.offset_right = 0
	add_child(logo)
	var sub := UiKit.label("talk to your neighbours. really talk.", 30, Color("#6b4a32"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_right = 1
	sub.position.y = 255
	add_child(sub)
	press = UiKit.label("Press Enter", 40, Color("#ffffff"))
	press.add_theme_color_override("font_outline_color", Color("#e07a5f"))
	press.add_theme_constant_override("outline_size", 14)
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.anchor_right = 1
	press.position.y = 360
	add_child(press)
	var tp := press.create_tween().set_loops()
	tp.tween_property(press, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tp.tween_property(press, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	var tl := logo.create_tween().set_loops()
	tl.tween_property(logo, "position:y", 100.0, 1.4).set_trans(Tween.TRANS_SINE)
	tl.tween_property(logo, "position:y", 110.0, 1.4).set_trans(Tween.TRANS_SINE)
	if OS.has_feature("web") and not Hotline.has_key():
		var note := UiKit.label("Voice calls need a Vapi public key: the page will ask for it.", 22, Color("#6b4a32"))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.anchor_right = 1
		note.position.y = 420
		add_child(note)
	var help := UiKit.label("WASD / arrows: walk    E / Space: talk    Esc: hang up", 20, Color("#ffffff"))
	help.add_theme_color_override("font_outline_color", Color("#3d6b45"))
	help.add_theme_constant_override("outline_size", 8)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.anchor_right = 1
	help.position.y = 670
	add_child(help)
	if OS.get_environment("HV_SHOT") != "":
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/hv_0_title.png")
		_go()

func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed and (e.physical_keycode == KEY_ENTER or e.physical_keycode == KEY_KP_ENTER or e.physical_keycode == KEY_SPACE)) \
		or (e is InputEventMouseButton and e.pressed):
		_go()

var _going := false
func _go() -> void:
	if _going:
		return
	_going = true
	Sfx.play("select")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
