class_name WorldGen
extends RefCounted

const CHUNK_SIZE          := 30   # Tiles per chunk (each axis)
const TILE_SIZE           := 16   # Pixels per tile
const CA_PASSES           := 5    # Cave-CA smoothing iterations
const SMOOTH_PASSES       := 2    # Float-density smoothing iterations after CA
const OVERLAP             := 7    # Border padding; must be ≥ CA_PASSES + SMOOTH_PASSES
const IMPASSABLE_THRESHOLD := 0.5  # density > this projects as wall (ADR-0003)

# Per-chunk generator parameter that biases the wall-fill probability. Spatially
# varied so the world has open regions and claustrophobic ones. Not stored anywhere
# — only used while seeding the CA. Distinct from the per-tile rock-density field
# that emerges after the CA + smoothing passes.
static func density_at(chunk_x: int, chunk_y: int) -> float:
	var fx := float(chunk_x)
	var fy := float(chunk_y)
	var n  := sin(fx * 0.23) * cos(fy * 0.19) + cos(fx * 0.11 - fy * 0.13) * 0.4
	return 0.47 + clampf(n / 1.4, -1.0, 1.0) * 0.10  # range ≈ [0.37, 0.57]

# Generate the per-tile float rock-density field for chunk (chunk_x, chunk_y).
# Pipeline: deterministic boolean hash → boolean CA (gives cave structure) →
# boolean→float lift → float smoothing passes (gives continuous gradients).
# Deterministic: same inputs always produce the same output.
static func generate_chunk(chunk_x: int, chunk_y: int, master_seed: int) -> Array:
	var origin_x := chunk_x * CHUNK_SIZE
	var origin_y := chunk_y * CHUNK_SIZE
	var ext      := CHUNK_SIZE + OVERLAP * 2  # Extended region size (each axis)
	var bias     := density_at(chunk_x, chunk_y)

	# Fill extended region from position hash — no RNG state, so any chunk can
	# sample any world cell and get the same value as its neighbour would.
	var bool_grid := []
	for ly in ext:
		var row := []
		for lx in ext:
			row.append(_hash_wall(
				origin_x - OVERLAP + lx,
				origin_y - OVERLAP + ly,
				master_seed,
				bias
			))
		bool_grid.append(row)

	# Cave CA. Padded by OVERLAP, so each interior cell's sphere-of-influence
	# never reaches the region boundary; chunks join seamlessly.
	for _i in CA_PASSES:
		bool_grid = _ca_step(bool_grid, ext)

	# Lift booleans to floats, then smooth to give continuous gradients.
	# Deep wall → ~1.0, deep cave → ~0.0, boundary cells in between.
	var float_grid := []
	for ly in ext:
		var row := []
		for lx in ext:
			row.append(1.0 if bool_grid[ly][lx] else 0.0)
		float_grid.append(row)

	for _i in SMOOTH_PASSES:
		float_grid = _smooth_step(float_grid, ext)

	# Trim the overlap border, returning only the chunk interior.
	var density := []
	for ly in CHUNK_SIZE:
		var row := []
		for lx in CHUNK_SIZE:
			row.append(float_grid[OVERLAP + ly][OVERLAP + lx])
		density.append(row)
	return density

# Initial vitality at a tile: sharpened inversion of density plus small per-tile noise.
# Deterministic from (world_x, world_y, master_seed).
static func initial_vitality(density: float, wx: int, wy: int, seed: int) -> float:
	var base := clampf((1.0 - density - 0.4) / 0.3, 0.0, 1.0)
	var h: int = seed ^ (wx * 0x27d4eb2d) ^ (wy * 0x165667b1)
	h ^= h >> 15
	h *= 0x1b873593
	h ^= h >> 16
	var noise := (float(h & 0xFFFF) / 65535.0 - 0.5) * 0.10  # ±0.05
	return clampf(base + noise, 0.0, 1.0)

# Deterministic wall/floor decision for a world-space tile using integer hashing.
# Works correctly for negative coordinates.
static func _hash_wall(wx: int, wy: int, seed: int, bias: float) -> bool:
	var h: int = seed ^ (wx * 0x9e3779b9) ^ (wy * 0x85ebca6b)
	h ^= h >> 16
	h *= 0x45d9f3b7
	h ^= h >> 16
	return (h & 0x7FFFFFFF) < int(bias * float(0x7FFFFFFF))

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

# 3×3 neighbourhood mean. Boundary cells use only their in-bounds neighbours
# (no synthetic wall padding — the OVERLAP buffer is wide enough that interior
# tiles never see the edge).
static func _smooth_step(grid: Array, size: int) -> Array:
	var next := []
	for y in size:
		var row := []
		for x in size:
			var sum   := 0.0
			var count := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						sum += grid[ny][nx]
						count += 1
			row.append(sum / float(count))
		next.append(row)
	return next
