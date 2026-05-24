class_name Creature
extends Node2D

const BASE_SPEED := 30.0
const PERCEPTION_RADIUS := 60.0
const BASE_ENERGY := 100.0
const ENERGY_FROM_MOSS := 12.0
const GRAZE_CHANCE := 0.08
const MUTATION_STD := 0.1
const MIN_SIZE := 0.3
const MAX_SIZE := 3.0
const REPRODUCE_COOLDOWN := 15.0

var strategy: Dictionary
var velocity := Vector2.ZERO
var energy: float = 0.0
var age := 0
var reproduce_timer: float = 0.0

static func random_strategy() -> Dictionary:
	return {
		speed = randf_range(0.5, 1.5),
		size = randf_range(0.4, 1.6),
		moss_seek = randf_range(-0.5, 1.5),
		prey_seek = randf_range(-0.5, 1.0),
		predator_flee = randf_range(0.0, 2.0),
		reproduce_threshold = randf_range(0.4, 0.8),
	}

static func mutate_strategy(parent: Dictionary) -> Dictionary:
	var s := parent.duplicate()
	for key in s:
		s[key] += randfn(0.0, MUTATION_STD)
	s.speed = clampf(s.speed, 0.2, 2.5)
	s.size = clampf(s.size, MIN_SIZE, MAX_SIZE)
	s.reproduce_threshold = clampf(s.reproduce_threshold, 0.2, 0.9)
	return s

func init_with(strat: Dictionary) -> void:
	strategy = strat
	energy = max_energy() * 0.7
	velocity = Vector2.from_angle(randf() * TAU) * max_speed() * 0.5
	reproduce_timer = REPRODUCE_COOLDOWN * randf()

func max_speed() -> float:
	return BASE_SPEED * strategy.speed

func max_energy() -> float:
	return BASE_ENERGY * strategy.size

func body_radius() -> float:
	return 2.0 + strategy.size * 2.0

func steer(creatures: Array, cm: ChunkManager) -> void:
	var accel := Vector2.ZERO
	accel += _sense_moss(cm) * strategy.moss_seek * 2.0

	var separation := Vector2.ZERO
	for other: Creature in creatures:
		if other == self:
			continue
		var offset := other.position - position
		var dist := offset.length()
		if dist > PERCEPTION_RADIUS or dist < 0.001:
			continue
		var dir := offset.normalized()

		if dist < 20.0:
			separation -= dir / dist

		if other.strategy.size < strategy.size * 0.8:
			accel += dir * strategy.prey_seek / maxf(dist * 0.1, 1.0)

		if other.strategy.size > strategy.size * 1.2:
			accel -= dir * strategy.predator_flee / maxf(dist * 0.05, 1.0)

	accel += separation * 1.5
	velocity = (velocity + accel).limit_length(max_speed())
	if velocity.length() < 3.0:
		velocity = velocity.normalized() * 3.0

func _sense_moss(cm: ChunkManager) -> Vector2:
	var ts := float(WorldGen.TILE_SIZE)
	var tx := floori(position.x / ts)
	var ty := floori(position.y / ts)
	var pull := Vector2.ZERO
	var radius := 4
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if cm.tile_at(tx + dx, ty + dy) == WorldGen.MOSS:
				var world_pos := Vector2((tx + dx) * ts + ts * 0.5, (ty + dy) * ts + ts * 0.5)
				var d := (world_pos - position).length()
				if d > 0.01:
					pull += (world_pos - position).normalized() / d
	return pull.normalized() if pull.length() > 0.01 else Vector2.ZERO

func graze(cm: ChunkManager) -> void:
	if strategy.moss_seek <= 0.0:
		return
	var ts := float(WorldGen.TILE_SIZE)
	var tx := floori(position.x / ts)
	var ty := floori(position.y / ts)
	if cm.tile_at(tx, ty) == WorldGen.MOSS and randf() < GRAZE_CHANCE:
		cm.set_tile_at(tx, ty, WorldGen.FLOOR)
		energy = minf(energy + ENERGY_FROM_MOSS, max_energy())

func try_eat(prey: Creature) -> bool:
	if prey.strategy.size >= strategy.size * 0.8:
		return false
	var dist := position.distance_to(prey.position)
	if dist > body_radius() + prey.body_radius():
		return false
	var ratio: float = prey.strategy.size / strategy.size
	if randf() > (1.0 - ratio):
		return false
	energy = minf(energy + prey.energy * 0.7, max_energy())
	return true

func tick_life() -> void:
	var drain: float = strategy.size * 0.5 + strategy.speed * 0.3
	energy -= drain
	age += 1
	reproduce_timer = maxf(0.0, reproduce_timer - 1.0)

func can_reproduce() -> bool:
	return reproduce_timer <= 0.0 and energy > max_energy() * strategy.reproduce_threshold

func reproduce() -> Creature:
	var child := Creature.new()
	child.init_with(Creature.mutate_strategy(strategy))
	child.position = position + Vector2.from_angle(randf() * TAU) * 10.0
	var share: float = energy * 0.35
	child.energy = share
	energy -= share
	child.reproduce_timer = REPRODUCE_COOLDOWN
	reproduce_timer = REPRODUCE_COOLDOWN
	return child

func is_dead() -> bool:
	return energy <= 0.0

func _draw() -> void:
	var r := body_radius()
	var green := clampf(strategy.moss_seek, 0.0, 1.0)
	var red := clampf(strategy.prey_seek, 0.0, 1.0)
	var blue := clampf(strategy.speed / 2.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, r, Color(red * 0.7 + 0.2, green * 0.5 + 0.2, blue * 0.5 + 0.2))
	var dir := velocity.normalized() * (r + 2.0)
	draw_line(Vector2.ZERO, dir, Color(1.0, 1.0, 1.0, 0.4), 1.0)
