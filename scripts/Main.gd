extends Node2D

var cm: ChunkManager = null
var player: Node2D = null
var hud: CanvasLayer = null
var readout: Label = null

var tick_rate: float = 2.0
var tick_accum: float = 0.0
var footstep_moss_chance: float = 0.15
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
			tick_rate += 1.0
		KEY_MINUS:
			if cm != null:
				cm.moss_probability = max(0.05, cm.moss_probability - 0.05)
		KEY_EQUAL:
			if cm != null:
				cm.moss_probability = min(0.95, cm.moss_probability + 0.05)

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
		if _last_player_tile.x != 0x7FFFFFFF and cm.tile_at(_last_player_tile.x, _last_player_tile.y) == WorldGen.FLOOR:
			if randf() < footstep_moss_chance:
				cm.set_tile_at(_last_player_tile.x, _last_player_tile.y, WorldGen.MOSS)
		_last_player_tile = current_tile

	if not cm.paused:
		tick_accum += delta
		var tick_interval := 1.0 / tick_rate
		while tick_accum >= tick_interval:
			tick_accum -= tick_interval
			cm.world_tick(player.tile_position() as Vector2i)

	var stats: Dictionary = cm.tile_stats()
	var tp: Vector2i = player.tile_position()
	var under: int = cm.tile_at(tp.x, tp.y)
	var under_str := "Blight" if under == WorldGen.BLIGHT else ("Moss" if under == WorldGen.MOSS else "Floor")
	var paused_tag := "  (PAUSED)" if cm.paused else ""
	readout.text = "tick %d  rate %.0f Hz%s\nmoss %d  blight %d  / %d\nunderfoot %s  tile (%d, %d)\nseed prob %.0f%%\n[/] tick rate  -/= seed prob  F pause  R restart" % [
		cm.tick_count, tick_rate, paused_tag,
		stats.moss, stats.blight, stats.total,
		under_str, tp.x, tp.y,
		cm.moss_probability * 100.0
	]
