extends Node2D

func _ready() -> void:
	randomize()
	_start(randi())

func _unhandled_input(event: InputEvent) -> void:
	# R → new world with a fresh seed
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		for child in get_children():
			child.queue_free()
		_start(randi())

func _start(seed_val: int) -> void:
	var cm := ChunkManager.new()
	cm.name = "ChunkManager"
	cm.setup(seed_val)
	add_child(cm)

	# Load the chunks around the origin so we can find a spawn tile.
	cm.refresh(Vector2.ZERO)

	var spawn := _find_spawn(cm)

	var player := Node2D.new()
	player.name = "Player"
	player.set_script(preload("res://scripts/Player.gd"))
	player.chunk_manager = cm
	add_child(player)

	var ts := float(WorldGen.TILE_SIZE)
	player.position = Vector2(spawn.x * ts + ts * 0.5, spawn.y * ts + ts * 0.5)

func _find_spawn(cm: ChunkManager) -> Vector2i:
	# Scan tiles near the origin for the first open floor cell.
	for y in range(-WorldGen.CHUNK_SIZE, WorldGen.CHUNK_SIZE * 2):
		for x in range(-WorldGen.CHUNK_SIZE, WorldGen.CHUNK_SIZE * 2):
			if not cm.is_wall(x, y):
				return Vector2i(x, y)
	return Vector2i(0, 0)
