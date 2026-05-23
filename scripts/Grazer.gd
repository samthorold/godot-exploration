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
const REPRODUCE_DIST := 25.0
const REPRODUCE_COOLDOWN := 10.0
const REPRODUCE_CHANCE := 0.05
const ENERGY_MAX := 100.0
const ENERGY_DRAIN := 1.0
const ENERGY_FROM_MOSS := 15.0

var velocity := Vector2.ZERO
var energy := ENERGY_MAX
var reproduce_timer := REPRODUCE_COOLDOWN * randf()

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
		energy = minf(energy + ENERGY_FROM_MOSS, ENERGY_MAX)

func tick_life(delta_ticks: float) -> void:
	energy -= ENERGY_DRAIN * delta_ticks
	reproduce_timer = maxf(0.0, reproduce_timer - delta_ticks)

func can_reproduce() -> bool:
	return reproduce_timer <= 0.0 and energy > ENERGY_MAX * 0.5

func try_reproduce_with(other: Grazer) -> Grazer:
	if not can_reproduce() or not other.can_reproduce():
		return null
	var dist := position.distance_to(other.position)
	if dist > REPRODUCE_DIST or randf() > REPRODUCE_CHANCE:
		return null
	reproduce_timer = REPRODUCE_COOLDOWN
	other.reproduce_timer = REPRODUCE_COOLDOWN
	var child := Grazer.new()
	child.position = (position + other.position) * 0.5
	child.velocity = Vector2.from_angle(randf() * TAU) * MAX_SPEED * 0.3
	child.reproduce_timer = REPRODUCE_COOLDOWN
	child.energy = (energy + other.energy) * 0.25
	energy *= 0.75
	other.energy *= 0.75
	return child

func is_starved() -> bool:
	return energy <= 0.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.4, 0.7, 0.9))
	var dir := velocity.normalized() * 4.0
	draw_line(Vector2.ZERO, dir, Color(0.5, 0.8, 1.0), 1.0)
