class_name Grazer
extends Node2D

const MAX_SPEED := 30.0
const PERCEPTION_RADIUS := 60.0
const SEPARATION_DIST := 20.0

const SEPARATION_WEIGHT := 1.5
const COHESION_WEIGHT := 1.0
const ALIGNMENT_WEIGHT := 1.0
const MOSS_WEIGHT := 2.0

const GRAZE_CHANCE := 0.08

var velocity := Vector2.ZERO

func _ready() -> void:
	velocity = Vector2.from_angle(randf() * TAU) * MAX_SPEED * 0.5

func steer(neighbours: Array[Grazer], cm: ChunkManager) -> void:
	var separation := Vector2.ZERO
	var cohesion := Vector2.ZERO
	var alignment := Vector2.ZERO
	var count := 0

	for other in neighbours:
		if other == self:
			continue
		var offset := position - other.position
		var dist := offset.length()
		if dist > PERCEPTION_RADIUS or dist < 0.001:
			continue
		count += 1
		cohesion += other.position
		alignment += other.velocity
		if dist < SEPARATION_DIST:
			separation += offset.normalized() / dist

	if count > 0:
		cohesion = (cohesion / float(count) - position).normalized()
		alignment = (alignment / float(count)).normalized()

	var moss_dir := _sense_moss(cm)

	var accel := (
		separation * SEPARATION_WEIGHT +
		cohesion * COHESION_WEIGHT +
		alignment * ALIGNMENT_WEIGHT +
		moss_dir * MOSS_WEIGHT
	)

	velocity = (velocity + accel).limit_length(MAX_SPEED)
	if velocity.length() < 5.0:
		velocity = velocity.normalized() * 5.0

func _sense_moss(cm: ChunkManager) -> Vector2:
	var ts := float(WorldGen.TILE_SIZE)
	var tx := floori(position.x / ts)
	var ty := floori(position.y / ts)
	var pull := Vector2.ZERO
	var radius := 5
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if cm.tile_at(tx + dx, ty + dy) == WorldGen.MOSS:
				var world_pos := Vector2((tx + dx) * ts + ts * 0.5, (ty + dy) * ts + ts * 0.5)
				var offset := world_pos - position
				var dist := offset.length()
				if dist > 0.01:
					pull += offset.normalized() / dist
	return pull.normalized() if pull.length() > 0.01 else Vector2.ZERO

func graze(cm: ChunkManager) -> void:
	var ts := float(WorldGen.TILE_SIZE)
	var tx := floori(position.x / ts)
	var ty := floori(position.y / ts)
	if cm.tile_at(tx, ty) == WorldGen.MOSS and randf() < GRAZE_CHANCE:
		cm.set_tile_at(tx, ty, WorldGen.FLOOR)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.4, 0.7, 0.9))
	var dir := velocity.normalized() * 4.0
	draw_line(Vector2.ZERO, dir, Color(0.5, 0.8, 1.0), 1.0)
