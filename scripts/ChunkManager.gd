class_name ChunkManager
extends Node2D

const VIEW_RADIUS := 2

var master_seed: int = 0
var moss_probability: float = 0.35
var tick_count: int = 0
var paused: bool = false

# Vector2i(chunk_x, chunk_y) → { tiles: Array[Array[int]], node: Node2D,
#   tint_img: Image, tint_tex: ImageTexture }
var _chunks: Dictionary = {}

func setup(seed_val: int) -> void:
	master_seed = seed_val

func ensure_loaded(world_pos: Vector2) -> void:
	var px := _chunk_coord(world_pos.x)
	var py := _chunk_coord(world_pos.y)
	for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var key := Vector2i(px + dx, py + dy)
			if key not in _chunks:
				_load(key)

func world_tick(player_tile: Vector2i) -> void:
	if paused:
		return
	var cs := WorldGen.CHUNK_SIZE

	var next_grids: Dictionary = {}
	for key: Vector2i in _chunks:
		var current: Array = _chunks[key].tiles
		var next := []
		for ly in cs:
			var row := []
			for lx in cs:
				var wx := key.x * cs + lx
				var wy := key.y * cs + ly
				var counts := _count_neighbours(wx, wy, player_tile)
				var cell: int = current[ly][lx]
				row.append(_next_cell(cell, counts.moss, counts.blight))
			next.append(row)
		next_grids[key] = next

	for key: Vector2i in next_grids:
		_chunks[key].tiles = next_grids[key]
		_redraw_tint(key)
	tick_count += 1

func _next_cell(cell: int, moss_n: int, blight_n: int) -> int:
	match cell:
		WorldGen.MOSS:
			if blight_n >= 1:
				return WorldGen.BLIGHT
			if moss_n >= 5 and randf() < 0.01:
				return WorldGen.BLIGHT
			return WorldGen.MOSS if moss_n >= 2 and moss_n <= 3 else WorldGen.FLOOR
		WorldGen.BLIGHT:
			return WorldGen.BLIGHT if moss_n >= 1 else WorldGen.FLOOR
		_:
			return WorldGen.MOSS if moss_n == 3 else WorldGen.FLOOR

func set_tile_at(wx: int, wy: int, tile_type: int) -> void:
	var cs := WorldGen.CHUNK_SIZE
	var cx := floori(float(wx) / float(cs))
	var cy := floori(float(wy) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return
	_chunks[key].tiles[wy - cy * cs][wx - cx * cs] = tile_type
	_redraw_tint(key)

func tile_at(wx: int, wy: int) -> int:
	var cs := WorldGen.CHUNK_SIZE
	var cx := floori(float(wx) / float(cs))
	var cy := floori(float(wy) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return WorldGen.FLOOR
	return _chunks[key].tiles[wy - cy * cs][wx - cx * cs]

func tile_stats() -> Dictionary:
	var moss := 0
	var blight := 0
	var total := 0
	var cs := WorldGen.CHUNK_SIZE
	for key: Vector2i in _chunks:
		var tiles: Array = _chunks[key].tiles
		for ly in cs:
			for lx in cs:
				total += 1
				if tiles[ly][lx] == WorldGen.MOSS:
					moss += 1
				elif tiles[ly][lx] == WorldGen.BLIGHT:
					blight += 1
	return {moss = moss, blight = blight, total = total}

# --- private ---------------------------------------------------------------

func _chunk_coord(world_axis: float) -> int:
	return floori(world_axis / float(WorldGen.CHUNK_SIZE * WorldGen.TILE_SIZE))

func _count_neighbours(wx: int, wy: int, player_tile: Vector2i) -> Dictionary:
	var moss := 0
	var blight := 0
	var cs := WorldGen.CHUNK_SIZE
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := wx + dx
			var ny := wy + dy
			if nx == player_tile.x and ny == player_tile.y:
				moss += 1
				continue
			var cx := floori(float(nx) / float(cs))
			var cy := floori(float(ny) / float(cs))
			var ckey := Vector2i(cx, cy)
			if ckey not in _chunks:
				continue
			var tile: int = _chunks[ckey].tiles[ny - cy * cs][nx - cx * cs]
			if tile == WorldGen.MOSS:
				moss += 1
			elif tile == WorldGen.BLIGHT:
				blight += 1
	return {moss = moss, blight = blight}

func _load(key: Vector2i) -> void:
	var tiles := WorldGen.generate_chunk(key.x, key.y, master_seed, moss_probability)
	var cs := WorldGen.CHUNK_SIZE
	var ts := WorldGen.TILE_SIZE

	var img := Image.create(cs, cs, false, Image.FORMAT_RGB8)
	_fill_tint_image(img, tiles)
	var tex := ImageTexture.create_from_image(img)

	var sprite := Sprite2D.new()
	sprite.texture        = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered       = false
	sprite.scale          = Vector2(ts, ts)

	var node := Node2D.new()
	node.position = Vector2(key.x * cs * ts, key.y * cs * ts)
	node.add_child(sprite)
	add_child(node)

	_chunks[key] = {
		tiles   = tiles,
		node    = node,
		tint_img = img,
		tint_tex = tex,
	}

func _fill_tint_image(img: Image, tiles: Array) -> void:
	var cs := WorldGen.CHUNK_SIZE
	for ly in cs:
		for lx in cs:
			img.set_pixel(lx, ly, _tile_color(tiles[ly][lx]))

func _tile_color(tile_type: int) -> Color:
	match tile_type:
		WorldGen.MOSS:
			return Color(0.25, 0.55, 0.20)
		WorldGen.BLIGHT:
			return Color(0.65, 0.20, 0.12)
		_:
			return Color(0.15, 0.12, 0.10)

func _redraw_tint(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	_fill_tint_image(chunk.tint_img, chunk.tiles)
	chunk.tint_tex.update(chunk.tint_img)
