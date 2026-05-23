class_name ChunkManager
extends Node2D

const VIEW_RADIUS   := 2
const REVEAL_RADIUS := 8

# ceil(CHUNK_SIZE² / 8) — one bit per tile, packed into bytes.
const BITMAP_SIZE := (WorldGen.CHUNK_SIZE * WorldGen.CHUNK_SIZE + 7) / 8  # 113

var master_seed: int = 0

# Vector2i(chunk_x, chunk_y) → { tiles: Array, node: Node2D }
var _chunks: Dictionary = {}

# Explored state: Vector2i(chunk) → PackedByteArray(BITMAP_SIZE).
# One bit per tile; persists across chunk eviction.
var _explored_chunks: Dictionary = {}

# Per-loaded-chunk fog data for incremental GPU updates.
# Vector2i(chunk) → { img: Image, tex: ImageTexture }
var _fog: Dictionary = {}

func setup(seed_val: int) -> void:
	master_seed = seed_val

func refresh(world_pos: Vector2) -> void:
	var px := _chunk_coord(world_pos.x)
	var py := _chunk_coord(world_pos.y)

	for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var key := Vector2i(px + dx, py + dy)
			if key not in _chunks:
				_load(key)

	var evict_radius := VIEW_RADIUS + 1
	for key: Vector2i in _chunks.keys():
		if abs(key.x - px) > evict_radius or abs(key.y - py) > evict_radius:
			_unload(key)

	reveal_around(world_pos)

func is_wall(world_x: int, world_y: int) -> bool:
	var cs  := WorldGen.CHUNK_SIZE
	var cx  := floori(float(world_x) / float(cs))
	var cy  := floori(float(world_y) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return true
	var lx := world_x - cx * cs
	var ly := world_y - cy * cs
	return _chunks[key].tiles[ly][lx]

func reveal_around(world_pos: Vector2) -> void:
	var ts := WorldGen.TILE_SIZE
	var cs := WorldGen.CHUNK_SIZE
	var tx := floori(world_pos.x / float(ts))
	var ty := floori(world_pos.y / float(ts))

	var dirty: Dictionary = {}  # Vector2i(chunk) → Array of local Vector2i coords

	for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			if dx * dx + dy * dy > REVEAL_RADIUS * REVEAL_RADIUS:
				continue
			var wx := tx + dx
			var wy := ty + dy
			var ck := Vector2i(floori(float(wx) / float(cs)), floori(float(wy) / float(cs)))
			var lx := wx - ck.x * cs
			var ly := wy - ck.y * cs
			if _get_bit(ck, lx, ly):
				continue
			_set_bit(ck, lx, ly)
			if ck not in dirty:
				dirty[ck] = []
			dirty[ck].append(Vector2i(lx, ly))

	for ck: Vector2i in dirty:
		if ck not in _fog:
			continue
		var img: Image        = _fog[ck].img
		var tex: ImageTexture = _fog[ck].tex
		for local: Vector2i in dirty[ck]:
			img.fill_rect(Rect2i(local.x * ts, local.y * ts, ts, ts), Color(0, 0, 0, 0))
		tex.update(img)

# --- private -----------------------------------------------------------------

func _chunk_coord(world_axis: float) -> int:
	return floori(world_axis / float(WorldGen.CHUNK_SIZE * WorldGen.TILE_SIZE))

func _load(key: Vector2i) -> void:
	var tiles := WorldGen.generate_chunk(key.x, key.y, master_seed)
	var node  := _render(key, tiles)
	_attach_fog(key, node)
	_chunks[key] = {tiles = tiles, node = node}

func _unload(key: Vector2i) -> void:
	_chunks[key].node.queue_free()
	_fog.erase(key)
	_chunks.erase(key)

func _render(key: Vector2i, tiles: Array) -> Node2D:
	var ts  := WorldGen.TILE_SIZE
	var cs  := WorldGen.CHUNK_SIZE
	var img := Image.create(cs * ts, cs * ts, false, Image.FORMAT_RGB8)

	# t=0 open/warm, t=1 dense/cool — gives the density landscape a visible identity.
	var t := (WorldGen.density_at(key.x, key.y) - 0.37) / 0.20
	var floor_a := Color(0.54, 0.48, 0.39).lerp(Color(0.38, 0.42, 0.50), t)
	var floor_b := Color(0.50, 0.44, 0.36).lerp(Color(0.34, 0.38, 0.46), t)

	for ly in cs:
		for lx in cs:
			var color: Color
			if tiles[ly][lx]:
				color = Color(0.18, 0.14, 0.12)
			else:
				color = floor_a if (lx + ly) % 2 == 0 else floor_b
			img.fill_rect(Rect2i(lx * ts, ly * ts, ts, ts), color)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = false

	var node := Node2D.new()
	node.position = Vector2(key.x * cs * ts, key.y * cs * ts)
	node.add_child(sprite)
	add_child(node)
	return node

func _attach_fog(key: Vector2i, chunk_node: Node2D) -> void:
	var ts  := WorldGen.TILE_SIZE
	var cs  := WorldGen.CHUNK_SIZE
	var img := Image.create(cs * ts, cs * ts, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))

	for ly in cs:
		for lx in cs:
			if _get_bit(key, lx, ly):
				img.fill_rect(Rect2i(lx * ts, ly * ts, ts, ts), Color(0, 0, 0, 0))

	var tex    := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture  = tex
	sprite.centered = false
	chunk_node.add_child(sprite)

	_fog[key] = {img = img, tex = tex}

# --- bitmap helpers ----------------------------------------------------------

func _get_bit(ck: Vector2i, lx: int, ly: int) -> bool:
	if ck not in _explored_chunks:
		return false
	var idx := ly * WorldGen.CHUNK_SIZE + lx
	return (_explored_chunks[ck][idx >> 3] >> (idx & 7)) & 1 == 1

func _set_bit(ck: Vector2i, lx: int, ly: int) -> void:
	if ck not in _explored_chunks:
		var bmp := PackedByteArray()
		bmp.resize(BITMAP_SIZE)
		bmp.fill(0)
		_explored_chunks[ck] = bmp
	var idx := ly * WorldGen.CHUNK_SIZE + lx
	_explored_chunks[ck][idx >> 3] |= (1 << (idx & 7))
