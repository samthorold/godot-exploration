extends Node2D

const SPEED     := 160.0
const HALF_SIZE := 6.0  # Collision half-extent; slightly under TILE_SIZE/2

var chunk_manager: ChunkManager = null

# The player as a mobile field-cell (CONTEXT.md / Mobile field-cell).
# capacity > 1 — structural encoding of the player as a stabiliser/perturber.
var vitality: float = 0.5
var capacity: float = 5.0

func _ready() -> void:
	var cam := Camera2D.new()
	cam.enabled = true
	add_child(cam)

func _process(delta: float) -> void:
	if chunk_manager == null:
		return

	# Let the chunk manager react to our current position before moving.
	chunk_manager.refresh(position)

	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up",   "ui_down")
	)
	if dir != Vector2.ZERO:
		dir = dir.normalized()

	var ts      := float(WorldGen.TILE_SIZE)
	var desired := position + dir * SPEED * delta

	# Try full movement first; fall back to axis-separated sliding on walls.
	if _can_occupy(desired, ts):
		position = desired
	else:
		var h := position + Vector2(dir.x, 0.0) * SPEED * delta
		if _can_occupy(h, ts):
			position = h
		var v := position + Vector2(0.0, dir.y) * SPEED * delta
		if _can_occupy(v, ts):
			position = v

	# One evolve tick per frame, after position is settled.
	chunk_manager.evolve(delta, [self])
	queue_redraw()

func _can_occupy(pos: Vector2, ts: float) -> bool:
	for dy in [-HALF_SIZE, HALF_SIZE]:
		for dx in [-HALF_SIZE, HALF_SIZE]:
			var corner := pos + Vector2(dx, dy)
			if chunk_manager.is_wall(floori(corner.x / ts), floori(corner.y / ts)):
				return false
	return true

func _draw() -> void:
	var dead  := Color(0.40, 0.34, 0.24)
	var vital := Color(1.00, 0.70, 0.20)
	var body  := dead.lerp(vital, vitality)
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0), body)
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.95, 0.70))
