class_name ChunkManager
extends Node2D

# Chunks loaded in each direction from the player's current chunk.
# VIEW_RADIUS=2 → 5×5 = 25 chunks active at most.
const VIEW_RADIUS := 2

var master_seed: int = 0

# Vector2i(chunk_x, chunk_y) → { tiles: Array, node: Node2D }
var _chunks: Dictionary = {}

func setup(seed_val: int) -> void:
	master_seed = seed_val

# Called every frame by the player.  Loads chunks near world_pos and frees
# those that have moved out of range.
func refresh(world_pos: Vector2) -> void:
	var px := _chunk_coord(world_pos.x)
	var py := _chunk_coord(world_pos.y)

	for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var key := Vector2i(px + dx, py + dy)
			if key not in _chunks:
				_load(key)

	# Unload with one chunk of hysteresis so we don't thrash on the boundary.
	var evict_radius := VIEW_RADIUS + 1
	for key: Vector2i in _chunks.keys():
		if abs(key.x - px) > evict_radius or abs(key.y - py) > evict_radius:
			_unload(key)

func is_wall(world_x: int, world_y: int) -> bool:
	var cs  := WorldGen.CHUNK_SIZE
	var cx  := floori(float(world_x) / float(cs))
	var cy  := floori(float(world_y) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return true  # Treat unloaded area as impassable
	var lx := world_x - cx * cs
	var ly := world_y - cy * cs
	return _chunks[key].tiles[ly][lx]

# --- private -----------------------------------------------------------------

func _chunk_coord(world_axis: float) -> int:
	return floori(world_axis / float(WorldGen.CHUNK_SIZE * WorldGen.TILE_SIZE))

func _load(key: Vector2i) -> void:
	var tiles := WorldGen.generate_chunk(key.x, key.y, master_seed)
	var node  := _render(key, tiles)
	_chunks[key] = {tiles = tiles, node = node}

func _unload(key: Vector2i) -> void:
	_chunks[key].node.queue_free()
	_chunks.erase(key)

func _render(key: Vector2i, tiles: Array) -> Node2D:
	var ts  := WorldGen.TILE_SIZE
	var cs  := WorldGen.CHUNK_SIZE
	var img := Image.create(cs * ts, cs * ts, false, Image.FORMAT_RGB8)

	for ly in cs:
		for lx in cs:
			var color: Color
			if tiles[ly][lx]:
				color = Color(0.18, 0.14, 0.12)  # Wall
			else:
				# Subtle checkerboard variation so large open floors aren't flat.
				color = Color(0.54, 0.48, 0.39) if (lx + ly) % 2 == 0 else Color(0.50, 0.44, 0.36)
			img.fill_rect(Rect2i(lx * ts, ly * ts, ts, ts), color)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = false

	var node := Node2D.new()
	node.position = Vector2(key.x * cs * ts, key.y * cs * ts)
	node.add_child(sprite)
	add_child(node)
	return node
