extends Node2D
## One crop on a soil tile. Grows through the 4 Basic Plants stages while watered.

const PLANTS := "res://assets/sprout/Objects/Basic Plants.png"
const ROWS := {"wheat": 0, "tomato": 1}

var kind := "wheat"
var stage := 1          # 1..4 (4 = ready)
var watered := false
var stage_time := 12.0
var t := 0.0
var sprite: Sprite2D

func setup(k: String, st: float) -> void:
	kind = k
	stage_time = st

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.offset = Vector2(0, -6)
	sprite.position = Vector2(0, 6)
	add_child(sprite)
	_apply()
	_squash(1.5)

func _apply() -> void:
	sprite.texture = Art.atlas(PLANTS, Rect2(stage * 16, ROWS[kind] * 16, 16, 16))

func ready_to_harvest() -> bool:
	return stage >= 4

func progress() -> float:
	return clampf((stage - 1 + t / stage_time) / 3.0, 0.0, 1.0)

func _process(delta: float) -> void:
	if not watered or stage >= 4:
		return
	t += delta
	if t >= stage_time:
		t = 0.0
		stage += 1
		_apply()
		_squash(1.35)
		if stage >= 4:
			Fx.burst(get_parent(), position + Vector2(0, -6), "sparkle")
			Sfx.play("pop", 0.1)
			_bob()

func wiggle() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", 0.25, 0.06)
	tw.tween_property(sprite, "rotation", -0.2, 0.08)
	tw.tween_property(sprite, "rotation", 0.0, 0.08)

func _squash(amount: float) -> void:
	sprite.scale = Vector2(1.0 / amount, amount)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _bob() -> void:
	# gentle ready pulse so ripe crops read at a glance
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "scale", Vector2(1.08, 0.94), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
