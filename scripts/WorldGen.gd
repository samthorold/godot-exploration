class_name WorldGen
extends RefCounted

const CHUNK_SIZE := 30  # Tiles per chunk (each axis)
const TILE_SIZE  := 16  # Pixels per tile
const CA_PASSES  := 5   # Smoothing iterations
const OVERLAP    := 5   # Border padding; must equal CA_PASSES for seamless edges
const DENSITY    := 0.47

# Generate the CHUNK_SIZE × CHUNK_SIZE tile grid for chunk (chunk_x, chunk_y).
# Deterministic: same inputs always produce the same output.
static func generate_chunk(chunk_x: int, chunk_y: int, master_seed: int) -> Array:
	var origin_x := chunk_x * CHUNK_SIZE
	var origin_y := chunk_y * CHUNK_SIZE
	var ext      := CHUNK_SIZE + OVERLAP * 2  # Extended region size (each axis)

	# Fill extended region from position hash — no RNG state, so any chunk can
	# sample any world cell and get the same value as its neighbour would.
	var grid := []
	for ly in ext:
		var row := []
		for lx in ext:
			row.append(_hash_wall(
				origin_x - OVERLAP + lx,
				origin_y - OVERLAP + ly,
				master_seed
			))
		grid.append(row)

	# Smooth with CA.  Because the extended region is padded by exactly OVERLAP
	# tiles, the CA's sphere-of-influence for any interior cell never reaches
	# the region boundary, so all interior cells are consistent across chunks.
	for _i in CA_PASSES:
		grid = _ca_step(grid, ext)

	# Trim the overlap border, returning only the chunk interior.
	var tiles := []
	for ly in CHUNK_SIZE:
		var row := []
		for lx in CHUNK_SIZE:
			row.append(grid[OVERLAP + ly][OVERLAP + lx])
		tiles.append(row)
	return tiles

# Deterministic wall/floor decision for a world-space tile using integer hashing.
# Works correctly for negative coordinates.
static func _hash_wall(wx: int, wy: int, seed: int) -> bool:
	var h: int = seed ^ (wx * 0x9e3779b9) ^ (wy * 0x85ebca6b)
	h ^= h >> 16
	h *= 0x45d9f3b7
	h ^= h >> 16
	return (h & 0x7FFFFFFF) < int(DENSITY * float(0x7FFFFFFF))

# Cave-gen cellular automaton: a cell is wall when five or more of its nine
# 3×3 neighbours (including itself) are wall.
static func _ca_step(grid: Array, size: int) -> Array:
	var next := []
	for y in size:
		var row := []
		for x in size:
			var walls := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or nx >= size or ny < 0 or ny >= size:
						walls += 1  # Boundary counts as wall
					elif grid[ny][nx]:
						walls += 1
			row.append(walls >= 5)
		next.append(row)
	return next
