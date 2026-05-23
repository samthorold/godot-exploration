extends Node2D

const SPEED := 160.0

func _ready() -> void:
	var cam := Camera2D.new()
	cam.enabled = true
	add_child(cam)

func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up",   "ui_down")
	)
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	position += dir * SPEED * delta
	queue_redraw()

func tile_position() -> Vector2i:
	var ts := float(WorldGen.TILE_SIZE)
	return Vector2i(floori(position.x / ts), floori(position.y / ts))

func _draw() -> void:
	var size := 6.0
	draw_rect(Rect2(-size, -size, size * 2.0, size * 2.0), Color(1.0, 0.9, 0.3))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.95, 0.70))
