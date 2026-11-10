class_name Fx
extends RefCounted
## Particle bursts + floating text helpers (world space).

static func burst(parent: Node, pos: Vector2, kind: String) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	match kind:
		"confetti":
			p.amount = 60
			p.lifetime = 1.6
			p.direction = Vector2(0, -1)
			p.spread = 70.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 130.0
			p.gravity = Vector2(0, 160)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.angular_velocity_min = -400
			p.angular_velocity_max = 400
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			g.colors = PackedColorArray([Color("#ff6f91"), Color("#ffc75f"), Color("#4fd1c5"), Color("#845ec2"), Color("#f9f871")])
			p.color_initial_ramp = g
		"sparkle":
			p.amount = 24
			p.lifetime = 0.9
			p.spread = 180.0
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 55.0
			p.gravity = Vector2.ZERO
			p.damping_min = 40
			p.damping_max = 60
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.color = Color("#fff3a0")
		_:
			p.amount = 12
			p.lifetime = 0.5
			p.spread = 180.0
			p.initial_velocity_min = 25.0
			p.initial_velocity_max = 45.0
			p.gravity = Vector2(0, 60)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.5
			p.color = Color("#ffffff")
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.z_index = 50
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func float_text(parent: Node, pos: Vector2, text: String, color := Color("#6b4a32")) -> void:
	var holder := Node2D.new()
	holder.z_index = 60
	holder.position = pos + Vector2(0, -12)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Art.world_font())
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#fff8e7"))
	l.add_theme_constant_override("outline_size", 14)
	holder.add_child(l)
	parent.add_child(holder)
	var sz := l.get_minimum_size()
	l.position = Vector2(-sz.x * 0.5, -sz.y * 0.5)
	holder.scale = Vector2.ZERO
	var t := holder.create_tween()
	t.tween_property(holder, "scale", Vector2(0.18, 0.18), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(holder, "position:y", holder.position.y - 14, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(holder, "modulate:a", 0.0, 0.35).set_delay(0.65)
	t.tween_callback(holder.queue_free)
