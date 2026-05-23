class_name ChunkManager
extends Node2D

const VIEW_RADIUS   := 2
const REVEAL_RADIUS := 8

# ceil(CHUNK_SIZE² / 8) — one bit per tile, packed into bytes.
const BITMAP_SIZE := (WorldGen.CHUNK_SIZE * WorldGen.CHUNK_SIZE + 7) / 8  # 113

var master_seed: int = 0

# Tuning parameters — live-tunable via Main's hotkeys.
# Disposable debug surface; not part of the design (CONTEXT.md / Local mixing).
var kappa: float = 0.5      # diffusion rate, per second
var frozen: bool = false    # pauses evolve

# Vector2i(chunk_x, chunk_y) → {
#   density:    Array[Array[float]],
#   vitality:   Array[Array[float]],
#   node:       Node2D,
#   tint_img:   Image,
#   tint_tex:   ImageTexture,
#   chunk_band: float,        # cached density_at(key.x, key.y) band for hue
# }
# Per-tile rock-density field; wall-ness is derived (ADR-0003).
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
	ensure_loaded(world_pos)
	reveal_around(world_pos)

# Loads (but does not reveal) the chunks within view of world_pos.
# Separated from refresh so callers that just need chunk data — like the
# spawn-finder — don't accidentally write to the explored bitmap.
func ensure_loaded(world_pos: Vector2) -> void:
	var px := _chunk_coord(world_pos.x)
	var py := _chunk_coord(world_pos.y)

	for dy in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var key := Vector2i(px + dx, py + dy)
			if key not in _chunks:
				_load(key)

	# Eviction is intentionally disabled in this prototype — the two-cadence
	# state-retention / replay-on-reload machinery is not yet built
	# (CONTEXT.md, Evolution). Sessions roam a bounded area.

func is_wall(world_x: int, world_y: int) -> bool:
	var cs  := WorldGen.CHUNK_SIZE
	var cx  := floori(float(world_x) / float(cs))
	var cy  := floori(float(world_y) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return true
	var lx := world_x - cx * cs
	var ly := world_y - cy * cs
	return _chunks[key].density[ly][lx] > WorldGen.IMPASSABLE_THRESHOLD

func vitality_at(world_x: int, world_y: int) -> float:
	var cs  := WorldGen.CHUNK_SIZE
	var cx  := floori(float(world_x) / float(cs))
	var cy  := floori(float(world_y) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return 0.0
	return _chunks[key].vitality[world_y - cy * cs][world_x - cx * cs]

func density_at_tile(world_x: int, world_y: int) -> float:
	var cs  := WorldGen.CHUNK_SIZE
	var cx  := floori(float(world_x) / float(cs))
	var cy  := floori(float(world_y) / float(cs))
	var key := Vector2i(cx, cy)
	if key not in _chunks:
		return 1.0
	return _chunks[key].density[world_y - cy * cs][world_x - cx * cs]

# One step of `evolve` (CONTEXT.md, Evolution). Single diffusion pass over
# the local-mixing graph: tile↔tile edges within and across chunk boundaries,
# plus mobile-cell↔underfoot-tile edges. Mass-weighted by field capacity.
# Jacobi-style: accumulate all deltas first, then apply.
func evolve(dt: float, mobile_cells: Array) -> void:
	if frozen:
		return
	var cs := WorldGen.CHUNK_SIZE

	# Allocate per-chunk delta grids
	var deltas: Dictionary = {}
	for key in _chunks:
		var grid := []
		for ly in cs:
			var row := []
			for lx in cs:
				row.append(0.0)
			grid.append(row)
		deltas[key] = grid

	# Tile↔tile edges — visit each edge once (right + down only)
	for key: Vector2i in _chunks:
		var v: Array = _chunks[key].vitality
		var d: Array = deltas[key]
		for ly in cs:
			for lx in cs:
				var v_self: float = v[ly][lx]
				# Right neighbour
				if lx + 1 < cs:
					var pair := _mix(v_self, 1.0, v[ly][lx + 1], 1.0, dt)
					d[ly][lx]     += pair[0]
					d[ly][lx + 1] += pair[1]
				else:
					var nkey := Vector2i(key.x + 1, key.y)
					if nkey in _chunks:
						var pair := _mix(v_self, 1.0, _chunks[nkey].vitality[ly][0], 1.0, dt)
						d[ly][lx]              += pair[0]
						deltas[nkey][ly][0]    += pair[1]
				# Down neighbour
				if ly + 1 < cs:
					var pair := _mix(v_self, 1.0, v[ly + 1][lx], 1.0, dt)
					d[ly][lx]     += pair[0]
					d[ly + 1][lx] += pair[1]
				else:
					var nkey := Vector2i(key.x, key.y + 1)
					if nkey in _chunks:
						var pair := _mix(v_self, 1.0, _chunks[nkey].vitality[0][lx], 1.0, dt)
						d[ly][lx]            += pair[0]
						deltas[nkey][0][lx]  += pair[1]

	# Mobile-cell↔underfoot edges
	var mobile_deltas: Array = []
	var ts := WorldGen.TILE_SIZE
	for cell in mobile_cells:
		var tx := floori(cell.position.x / float(ts))
		var ty := floori(cell.position.y / float(ts))
		var cx := floori(float(tx) / float(cs))
		var cy := floori(float(ty) / float(cs))
		var ckey := Vector2i(cx, cy)
		if ckey not in _chunks:
			mobile_deltas.append(0.0)
			continue
		var lx := tx - cx * cs
		var ly := ty - cy * cs
		var pair := _mix(cell.vitality, cell.capacity, _chunks[ckey].vitality[ly][lx], 1.0, dt)
		deltas[ckey][ly][lx] += pair[1]
		mobile_deltas.append(pair[0])

	# Apply deltas to tile fields, then redraw tint
	for key: Vector2i in _chunks:
		var v: Array = _chunks[key].vitality
		var d: Array = deltas[key]
		for ly in cs:
			for lx in cs:
				v[ly][lx] = clampf(v[ly][lx] + d[ly][lx], 0.0, 1.0)
		_redraw_tint(key)

	# Apply deltas to mobile cells
	for i in mobile_cells.size():
		mobile_cells[i].vitality = clampf(mobile_cells[i].vitality + mobile_deltas[i], 0.0, 1.0)

# Mass-weighted symmetric diffusion between two cells. Returns [delta_a, delta_b].
# Conserves m_a*v_a + m_b*v_b. CONTEXT.md / Local mixing, Field capacity.
func _mix(v_a: float, m_a: float, v_b: float, m_b: float, dt: float) -> Array:
	var m_total := m_a + m_b
	var v_eq    := (m_a * v_a + m_b * v_b) / m_total
	return [kappa * (v_eq - v_a) * dt, kappa * (v_eq - v_b) * dt]

func reveal_around(world_pos: Vector2) -> void:
	var ts := WorldGen.TILE_SIZE
	var cs := WorldGen.CHUNK_SIZE
	var tx := floori(world_pos.x / float(ts))
	var ty := floori(world_pos.y / float(ts))

	var dirty: Dictionary = {}

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
	var density  := WorldGen.generate_chunk(key.x, key.y, master_seed)
	var vitality := _make_vitality(key, density)

	var ts := WorldGen.TILE_SIZE
	var cs := WorldGen.CHUNK_SIZE
	var chunk_band := clampf((WorldGen.density_at(key.x, key.y) - 0.37) / 0.20, 0.0, 1.0)

	# One pixel per tile, scaled up by sprite with NEAREST filter — cheap GPU
	# upload on every per-frame redraw.
	var img := Image.create(cs, cs, false, Image.FORMAT_RGB8)
	_fill_tint_image(img, density, vitality, chunk_band)
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

	_attach_fog(key, node)
	_chunks[key] = {
		density    = density,
		vitality   = vitality,
		node       = node,
		tint_img   = img,
		tint_tex   = tex,
		chunk_band = chunk_band,
	}

func _make_vitality(key: Vector2i, density: Array) -> Array:
	var cs := WorldGen.CHUNK_SIZE
	var ox := key.x * cs
	var oy := key.y * cs
	var vit := []
	for ly in cs:
		var row := []
		for lx in cs:
			row.append(WorldGen.initial_vitality(density[ly][lx], ox + lx, oy + ly, master_seed))
		vit.append(row)
	return vit

func _fill_tint_image(img: Image, density: Array, vitality: Array, chunk_band: float) -> void:
	var cs := WorldGen.CHUNK_SIZE
	for ly in cs:
		for lx in cs:
			img.set_pixel(lx, ly, _tile_color(density[ly][lx], vitality[ly][lx], chunk_band))

# density-hue: warm cave / cool dense (chunk-level band).
# vitality-saturation: grey-dim at low vitality, full vivid colour at high.
func _tile_color(d: float, v: float, band: float) -> Color:
	if d > WorldGen.IMPASSABLE_THRESHOLD:
		var rock := Color(0.18, 0.14, 0.12)
		var moss := Color(0.22, 0.20, 0.14)
		return rock.lerp(moss, v)
	var warm := Color(0.54, 0.48, 0.39)
	var cool := Color(0.38, 0.42, 0.50)
	var hue  := warm.lerp(cool, band)
	var grey_val := (hue.r + hue.g + hue.b) / 3.0
	var grey := Color(grey_val, grey_val, grey_val) * 0.4
	var vivid := Color(min(hue.r * 1.15, 1.0), min(hue.g * 1.15, 1.0), min(hue.b * 1.15, 1.0))
	return grey.lerp(vivid, v)

func _redraw_tint(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	_fill_tint_image(chunk.tint_img, chunk.density, chunk.vitality, chunk.chunk_band)
	chunk.tint_tex.update(chunk.tint_img)

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
