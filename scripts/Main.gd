extends Node2D

var cm: ChunkManager = null
var player: Node2D = null
var hud: CanvasLayer = null
var readout: Label = null
var creatures: Array[Creature] = []

const INITIAL_POPULATION := 50

var tick_rate: float = 4.0
var tick_accum: float = 0.0
var _last_player_tile: Vector2i = Vector2i(0x7FFFFFFF, 0x7FFFFFFF)

func _ready() -> void:
	randomize()
	_start(randi())

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_R:
			for child in get_children():
				child.queue_free()
			_start(randi())
		KEY_F:
			if cm != null:
				cm.paused = not cm.paused
		KEY_BRACKETLEFT:
			tick_rate = max(1.0, tick_rate - 1.0)
		KEY_BRACKETRIGHT:
			tick_rate = min(60.0, tick_rate + 1.0)

func _start(seed_val: int) -> void:
	cm = ChunkManager.new()
	cm.name = "ChunkManager"
	cm.setup(seed_val)
	add_child(cm)

	cm.ensure_loaded(Vector2.ZERO)

	player = Node2D.new()
	player.name = "Player"
	player.set_script(preload("res://scripts/Player.gd"))
	add_child(player)
	player.position = Vector2.ZERO

	creatures.clear()
	for i in INITIAL_POPULATION:
		var c := Creature.new()
		c.init_with(Creature.random_strategy())
		c.position = Vector2(randf_range(-300, 300), randf_range(-300, 300))
		add_child(c)
		creatures.append(c)

	hud = CanvasLayer.new()
	readout = Label.new()
	readout.position = Vector2(10, 10)
	readout.add_theme_color_override("font_color", Color.WHITE)
	readout.add_theme_color_override("font_outline_color", Color.BLACK)
	readout.add_theme_constant_override("outline_size", 4)
	hud.add_child(readout)
	add_child(hud)

	tick_accum = 0.0

func _process(delta: float) -> void:
	if cm == null or player == null or readout == null:
		return

	cm.ensure_loaded(player.position)

	var current_tile: Vector2i = player.tile_position()
	if current_tile != _last_player_tile:
		_last_player_tile = current_tile

	for c in creatures:
		c.steer(creatures, cm)
		c.position += c.velocity * delta
		c.queue_redraw()

	if not cm.paused:
		tick_accum += delta
		var tick_interval := 1.0 / tick_rate
		while tick_accum >= tick_interval:
			tick_accum -= tick_interval
			_world_tick()

	_update_hud()

func _world_tick() -> void:
	cm.world_tick(player.tile_position() as Vector2i)

	for c in creatures:
		c.graze(cm)
		c.tick_life()

	# Predation: each creature tries to eat smaller nearby creatures
	var eaten: Array[Creature] = []
	for predator in creatures:
		if predator in eaten:
			continue
		for prey in creatures:
			if prey == predator or prey in eaten:
				continue
			if predator.try_eat(prey):
				eaten.append(prey)

	# Reproduction
	var births: Array[Creature] = []
	for c in creatures:
		if c in eaten:
			continue
		if c.can_reproduce():
			births.append(c.reproduce())

	for child in births:
		add_child(child)
		creatures.append(child)

	# Remove dead and eaten
	var i := creatures.size() - 1
	while i >= 0:
		if creatures[i].is_dead() or creatures[i] in eaten:
			creatures[i].queue_free()
			creatures.remove_at(i)
		i -= 1

func _update_hud() -> void:
	var stats: Dictionary = cm.tile_stats()
	var tp: Vector2i = player.tile_position()
	var under: int = cm.tile_at(tp.x, tp.y)
	var under_str := "Moss" if under == WorldGen.MOSS else "Floor"
	var paused_tag := "  (PAUSED)" if cm.paused else ""

	var avg_size := 0.0
	var avg_speed := 0.0
	for c in creatures:
		avg_size += c.strategy.size
		avg_speed += c.strategy.speed
	if creatures.size() > 0:
		avg_size /= creatures.size()
		avg_speed /= creatures.size()

	readout.text = "tick %d  rate %.0f Hz%s\nmoss %d / %d  creatures %d\navg size %.1f  avg speed %.1f\nunderfoot %s  tile (%d, %d)\n[/] tick rate  F pause  R restart" % [
		cm.tick_count, tick_rate, paused_tag,
		stats.moss, stats.total, creatures.size(),
		avg_size, avg_speed,
		under_str, tp.x, tp.y,
	]
