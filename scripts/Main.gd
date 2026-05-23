extends Node2D

var cm: ChunkManager = null
var player: Node2D = null
var hud: CanvasLayer = null
var readout: Label = null

func _ready() -> void:
	randomize()
	_start(randi())

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_R:
			# Restart with a fresh seed.
			for child in get_children():
				child.queue_free()
			_start(randi())
		KEY_F:
			if cm != null:
				cm.frozen = not cm.frozen
		KEY_BRACKETLEFT:
			if cm != null:
				cm.kappa = max(0.0, cm.kappa - 0.05)
		KEY_BRACKETRIGHT:
			if cm != null:
				cm.kappa += 0.05
		KEY_MINUS:
			if player != null:
				player.capacity = max(1.0, player.capacity - 1.0)
		KEY_EQUAL:
			if player != null:
				player.capacity += 1.0

func _start(seed_val: int) -> void:
	cm = ChunkManager.new()
	cm.name = "ChunkManager"
	cm.setup(seed_val)
	add_child(cm)

	# Load the chunks around the origin so we can find a spawn tile.
	# Use ensure_loaded (not refresh) — we don't want to reveal tiles around
	# the origin, only to be able to read them.
	cm.ensure_loaded(Vector2.ZERO)

	var spawn := _find_spawn(cm)

	player = Node2D.new()
	player.name = "Player"
	player.set_script(preload("res://scripts/Player.gd"))
	player.chunk_manager = cm
	add_child(player)

	var ts := float(WorldGen.TILE_SIZE)
	player.position = Vector2(spawn.x * ts + ts * 0.5, spawn.y * ts + ts * 0.5)

	# Debug HUD — disposable. Drops out when tuning settles.
	hud = CanvasLayer.new()
	readout = Label.new()
	readout.position = Vector2(10, 10)
	readout.add_theme_color_override("font_color", Color.WHITE)
	readout.add_theme_color_override("font_outline_color", Color.BLACK)
	readout.add_theme_constant_override("outline_size", 4)
	hud.add_child(readout)
	add_child(hud)

func _process(_delta: float) -> void:
	if cm == null or player == null or readout == null:
		return
	var ts := WorldGen.TILE_SIZE
	var tx := floori(player.position.x / float(ts))
	var ty := floori(player.position.y / float(ts))
	var v_tile := cm.vitality_at(tx, ty)
	var d_tile := cm.density_at_tile(tx, ty)
	var frozen_tag := "  (FROZEN)" if cm.frozen else ""
	readout.text = "player  v %.3f  m %.1f\ntile    v %.3f  d %.3f\nkappa %.2f%s\n[/] kappa   -/= capacity   F freeze   R restart" % [
		player.vitality, player.capacity, v_tile, d_tile, cm.kappa, frozen_tag
	]

func _find_spawn(cm_: ChunkManager) -> Vector2i:
	# Scan tiles near the origin for the first open floor cell.
	for y in range(-WorldGen.CHUNK_SIZE, WorldGen.CHUNK_SIZE * 2):
		for x in range(-WorldGen.CHUNK_SIZE, WorldGen.CHUNK_SIZE * 2):
			if not cm_.is_wall(x, y):
				return Vector2i(x, y)
	return Vector2i(0, 0)
