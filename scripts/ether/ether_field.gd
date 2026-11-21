extends Node3D
## Ether in the air above the ground area, stored as voxels.
##
## The space above the floor (up to `ether_height`) is split into cubes of
## `voxel_size`. 1 ether = 1 mana, and each voxel inside the ether region holds
## `ether_per_voxel` ether (set directly, not derived from the voxel's volume). The region
## is quantised to voxels, so its border is blocky.
##
## Drawing: a spell that summons mana calls `draw_ether()`. It drains the nearest voxel
## that still holds ether (measured to the closest point of the voxel), gradually, and
## moves on to the next nearest when that one is empty. Drained voxels stay empty (no
## recovery yet), so walking while summoning cleans a trail through the air.
## The voxels are also uploaded as a 3D texture that the display shaders read. By default
## violet motes float in the ether and dim with their voxel's ether (hidden when drained).
## Optionally (`show_bars`) each voxel is drawn as a see-through cube whose height is its
## ether amount, shrinking like a 3D bar until it is flat (hidden) when drained.

@export var player_path: NodePath = ^"../Player"
@export var floor_mesh_path: NodePath = ^"../GrassFloor/Mesh"
@export var environment_path: NodePath = ^"../WorldEnvironment"

enum EtherHalf { FULL, POS_X, NEG_X, POS_Z, NEG_Z }

## Which half of the ground has ether; the other half is empty. FULL = whole floor.
@export var ether_half: EtherHalf = EtherHalf.POS_Z

@export_group("Voxels")
## Edge length of one ether voxel, in metres.
@export var voxel_size: float = 0.5
## Height of the ether volume above the floor, in metres.
@export var ether_height: float = 4.0
## Ether held by one full voxel (1 ether = 1 mana, i.e. 1 unit of mana_radius). This is the
## knob for how much ether there is.
@export var ether_per_voxel: float = 0.003
## Farthest a spell can draw from, in metres. 0 = unlimited.
@export var max_reach: float = 0.0

@export_group("Look")
@export var ether_color: Color = Color(0.62, 0.4, 1.0)

@export_group("Inflow")
@export var inflow_count: int = 28
@export var inflow_lifetime: float = 0.7
@export var inflow_size: float = 0.07
@export var inflow_intensity: float = 1.6

@export_group("Motes")
## Violet motes floating in the ether; they dim as their voxel loses ether and vanish when it is empty.
@export var show_motes: bool = true
@export var mote_count: int = 2500
@export var mote_lifetime: float = 7.0
@export var mote_size: float = 0.14
@export var mote_intensity: float = 0.9
## Drift speed range of the motes (slow, so they rarely cross voxel borders).
@export var mote_speed_min: float = 0.01
@export var mote_speed_max: float = 0.06
## Far motes are scaled up by this factor so they stay visible as distinct lights.
@export var mote_far_scale: float = 2.5
## Half extents of the box (around the player) where motes spawn. Keep the height at
## half of `ether_height` so the box fills the ether volume.
@export var mote_area: Vector3 = Vector3(20.0, 2.0, 20.0)
@export var mote_fade_start: float = 18.0
@export var mote_fade_end: float = 28.0

@export_group("Voxel bars")
## Alternative display: one see-through cube per voxel whose height is its ether amount.
@export var show_bars: bool = false
## Voxel bars are drawn within this distance (metres) of the player, fading out at the edge.
@export var bar_view_radius: float = 8.0
## Opacity of the cube faces (low = see-through) and of the cube edges.
@export_range(0.0, 1.0) var bar_face_alpha: float = 0.04
@export_range(0.0, 1.0) var bar_edge_alpha: float = 0.3
## Thickness of the cube edge lines, in metres.
@export var bar_edge_width: float = 0.02
## Bars fade out close to the camera so they never block the view.
@export var bar_near_fade_start: float = 0.7
@export var bar_near_fade_end: float = 2.5

@export_group("Air")
@export var air_fog_density: float = 0.004
@export var air_fog_color: Color = Color(0.34, 0.22, 0.58)
## How much the violet air haze tints the sky. 0 = the sky keeps its normal colour inside the ether.
@export_range(0.0, 1.0) var air_fog_sky_affect: float = 0.0
@export var air_ambient_tint: Color = Color(0.94, 0.9, 1.0)
## Outside the ether area the ambient light is scaled by this (slightly darker).
@export var outside_energy_scale: float = 0.75
## How quickly the air tint follows the ether around the camera (higher = faster).
@export var air_tint_speed: float = 6.0

const BLOCK := 4  # voxels per side of the coarse blocks used to find the nearest ether quickly

## World position of the voxel grid's minimum corner (x, floor height, z) and its size.
var map_origin: Vector3 = Vector3(-30.0, 0.0, -30.0)
var map_size: Vector3 = Vector3(60.0, 4.0, 60.0)
## The ether region (XZ rectangle).
var region_center: Vector2 = Vector2.ZERO
var region_half: Vector2 = Vector2(30.0, 30.0)
## World height of the floor surface; there is no ether below it.
var floor_y: float = -INF

var _player: Node3D
var _floor_mesh: MeshInstance3D
var _env: Environment
var _motes: GPUParticles3D
var _mote_mat: ShaderMaterial
var _bars: MultiMeshInstance3D
var _bars_mat: ShaderMaterial
var _bar_half_x: int = 0
var _bar_half_z: int = 0
var _inflow_mat: ShaderMaterial
var _fade_ramp: GradientTexture1D

var _base_ambient_color: Color = Color.WHITE
var _base_ambient_energy: float = 1.0
var _base_fog_color: Color = Color.BLACK
var _air_e: float = 0.0

# Voxel storage: index = (y * _nz + z) * _nx + x, so each y layer is one contiguous image.
var _nx: int = 0
var _ny: int = 0
var _nz: int = 0
var _capacity: float = 0.125
var _mana: PackedFloat32Array = PackedFloat32Array()
var _bytes: PackedByteArray = PackedByteArray()
var _layers: Array[Image] = []
var _dirty_layers: PackedByteArray = PackedByteArray()
var _texture: ImageTexture3D
var _texture_dirty: bool = false

# Coarse blocks: how many non-empty voxels each block of BLOCK^3 voxels still has.
var _bx: int = 0
var _by: int = 0
var _bz: int = 0
var _block_count: PackedInt32Array = PackedInt32Array()

# Scratch results of the nearest-voxel search.
var _s_best: int = -1
var _s_d2: float = INF

## Spells currently drawing: {source, target, search_pos, from, last_draw, inflow}
var _sources: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("ether_field")

	_player = get_node_or_null(player_path) as Node3D
	_floor_mesh = get_node_or_null(floor_mesh_path) as MeshInstance3D

	var world_env := get_node_or_null(environment_path) as WorldEnvironment
	if world_env != null:
		_env = world_env.environment

	_build_fade_ramp()
	_read_region_from_floor()
	_build_voxels()
	_setup_air()
	_setup_motes()
	_setup_bars()
	_setup_inflow_material()


## Ether amount (0..1) at a world position: the voxels' fill, smoothly interpolated.
func ether_at(world_pos: Vector3) -> float:
	if _nx == 0 or world_pos.y < floor_y:
		return 0.0
	var g := (world_pos - map_origin) / voxel_size - Vector3(0.5, 0.5, 0.5)
	var x0 := floori(g.x)
	var y0 := floori(g.y)
	var z0 := floori(g.z)
	var fx := g.x - float(x0)
	var fy := g.y - float(y0)
	var fz := g.z - float(z0)

	var c00 := lerpf(_fill(x0, y0, z0), _fill(x0 + 1, y0, z0), fx)
	var c10 := lerpf(_fill(x0, y0 + 1, z0), _fill(x0 + 1, y0 + 1, z0), fx)
	var c01 := lerpf(_fill(x0, y0, z0 + 1), _fill(x0 + 1, y0, z0 + 1), fx)
	var c11 := lerpf(_fill(x0, y0 + 1, z0 + 1), _fill(x0 + 1, y0 + 1, z0 + 1), fx)
	return lerpf(lerpf(c00, c10, fy), lerpf(c01, c11, fy), fz)


## A spell summoning mana asks for `requested` units of mana (mana_radius). Returns how
## many it actually gets: it drains the nearest voxel that still has ether, then the next
## nearest, and so on. It gets less than requested only when there is not enough ether
## left (or none within `max_reach`).
func draw_ether(source: Node3D, requested: float) -> float:
	if requested <= 0.0 or _nx == 0:
		return 0.0

	var pos := source.global_position
	var src := _find_source(source)
	if src.is_empty():
		src = {
			"source": source,
			"target": -1,
			"search_pos": Vector3(INF, 0.0, 0.0),
			"from": pos,
			"last_draw": -100.0,
			"inflow": null,
		}

	var remaining := requested
	var granted := 0.0
	while remaining > 1e-9:
		var t: int = src["target"]
		var valid := t >= 0 and _mana[t] > 0.0
		# Re-check which voxel is nearest once the spell has moved a bit.
		if valid and pos.distance_to(src["search_pos"]) > voxel_size * 0.5:
			valid = false
		if not valid:
			t = _find_nearest(pos)
			src["search_pos"] = pos
			src["target"] = t
			if t < 0:
				break

		var take := minf(remaining, _mana[t])
		_remove_mana(t, take)
		granted += take
		remaining -= take
		src["from"] = _voxel_center(t)
		if _mana[t] <= 0.0:
			src["target"] = -1

	if granted > 0.0:
		if src["inflow"] == null:
			src["inflow"] = _make_inflow()
			_sources.append(src)
		src["last_draw"] = Time.get_ticks_msec() * 0.001
	return granted


func _process(delta: float) -> void:
	if _player != null and _motes != null:
		var p := _player.global_position
		_motes.global_position = Vector3(p.x, floor_y + mote_area.y, p.z)
	_update_bars()

	_update_sources()

	if _texture_dirty:
		_upload_texture()

	if _env != null:
		var cam := get_viewport().get_camera_3d()
		var sample_pos := Vector3.ZERO
		if cam != null:
			sample_pos = cam.global_position
		elif _player != null:
			sample_pos = _player.global_position
		# Smooth the voxel steps so crossing a voxel border doesn't pop the tint.
		_air_e = lerpf(_air_e, ether_at(sample_pos), 1.0 - exp(-air_tint_speed * delta))
		var e := _air_e
		_env.fog_density = air_fog_density * e
		_env.fog_light_color = _base_fog_color.lerp(air_fog_color, e)
		_env.ambient_light_color = _base_ambient_color.lerp(air_ambient_tint, e)
		_env.ambient_light_energy = _base_ambient_energy * lerpf(outside_energy_scale, 1.0, e)


# --- Voxels -----------------------------------------------------------------------

func _build_voxels() -> void:
	_nx = maxi(ceili(map_size.x / voxel_size - 0.0001), 1)
	_ny = maxi(ceili(map_size.y / voxel_size - 0.0001), 1)
	_nz = maxi(ceili(map_size.z / voxel_size - 0.0001), 1)
	_capacity = maxf(ether_per_voxel, 0.0001)

	_bx = ceili(float(_nx) / float(BLOCK))
	_by = ceili(float(_ny) / float(BLOCK))
	_bz = ceili(float(_nz) / float(BLOCK))

	var total := _nx * _ny * _nz
	_mana.resize(total)
	_bytes.resize(total)
	_block_count.resize(_bx * _by * _bz)
	_block_count.fill(0)

	# A voxel holds ether if its centre lies inside the region (blocky border).
	for z in _nz:
		var cz := map_origin.z + (float(z) + 0.5) * voxel_size
		var in_z := absf(cz - region_center.y) <= region_half.y
		for x in _nx:
			var cx := map_origin.x + (float(x) + 0.5) * voxel_size
			var inside := in_z and absf(cx - region_center.x) <= region_half.x
			for y in _ny:
				var idx := _index(x, y, z)
				if inside:
					_mana[idx] = _capacity
					_bytes[idx] = 255
					_block_count[_block_of(x, y, z)] += 1
				else:
					_mana[idx] = 0.0
					_bytes[idx] = 0

	_layers.clear()
	_dirty_layers.resize(_ny)
	_dirty_layers.fill(0)
	var layer_size := _nx * _nz
	for y in _ny:
		_layers.append(Image.create_from_data(
				_nx, _nz, false, Image.FORMAT_R8,
				_bytes.slice(y * layer_size, (y + 1) * layer_size)))
	_texture = ImageTexture3D.new()
	_texture.create(Image.FORMAT_R8, _nx, _nz, _ny, false, _layers)


func _upload_texture() -> void:
	var layer_size := _nx * _nz
	for y in _ny:
		if _dirty_layers[y] != 0:
			_layers[y].set_data(
					_nx, _nz, false, Image.FORMAT_R8,
					_bytes.slice(y * layer_size, (y + 1) * layer_size))
			_dirty_layers[y] = 0
	_texture.update(_layers)
	_texture_dirty = false


func _index(x: int, y: int, z: int) -> int:
	return (y * _nz + z) * _nx + x


func _block_of(x: int, y: int, z: int) -> int:
	return ((y / BLOCK) * _bz + (z / BLOCK)) * _bx + (x / BLOCK)


func _voxel_center(idx: int) -> Vector3:
	var x := idx % _nx
	var z := (idx / _nx) % _nz
	var y := idx / (_nx * _nz)
	return map_origin + (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * voxel_size


## Fill of a voxel (0 = empty, 1 = full); zero outside the grid.
func _fill(x: int, y: int, z: int) -> float:
	if x < 0 or y < 0 or z < 0 or x >= _nx or y >= _ny or z >= _nz:
		return 0.0
	return _mana[_index(x, y, z)] / _capacity


func _remove_mana(idx: int, amount: float) -> void:
	var before := _mana[idx]
	var after := maxf(before - amount, 0.0)
	if after < 1e-7:
		after = 0.0
	_mana[idx] = after
	# Any ether left keeps the byte above zero, so the voxel still counts as "not drained".
	_bytes[idx] = 0 if after <= 0.0 else maxi(int(roundf(after / _capacity * 255.0)), 1)

	var x := idx % _nx
	var z := (idx / _nx) % _nz
	var y := idx / (_nx * _nz)
	_dirty_layers[y] = 1
	_texture_dirty = true
	if before > 0.0 and after == 0.0:
		_block_count[_block_of(x, y, z)] -= 1


# --- Nearest voxel ----------------------------------------------------------------

## Index of the nearest voxel that still holds ether (distance to the closest point of
## the voxel), or -1 if there is none (within `max_reach`, if set).
func _find_nearest(p: Vector3) -> int:
	_s_best = -1
	_s_d2 = INF if max_reach <= 0.0 else max_reach * max_reach

	# Seed with the block around the point so most searches prune almost everything.
	var seed_block := _block_around(p)
	if _block_count[seed_block] > 0:
		_scan_block(seed_block, p)

	var span := float(BLOCK) * voxel_size
	var block_extent := Vector3(span, span, span)
	for by in _by:
		for bz in _bz:
			for bx in _bx:
				var b := (by * _bz + bz) * _bx + bx
				if b == seed_block or _block_count[b] == 0:
					continue
				var bmin := map_origin + Vector3(bx, by, bz) * span
				if _box_d2(p, bmin, bmin + block_extent) >= _s_d2:
					continue
				_scan_block(b, p)
	return _s_best


func _block_around(p: Vector3) -> int:
	var span := float(BLOCK) * voxel_size
	var g := (p - map_origin) / span
	var bx := clampi(floori(g.x), 0, _bx - 1)
	var by := clampi(floori(g.y), 0, _by - 1)
	var bz := clampi(floori(g.z), 0, _bz - 1)
	return (by * _bz + bz) * _bx + bx


func _scan_block(b: int, p: Vector3) -> void:
	var bx := b % _bx
	var bz := (b / _bx) % _bz
	var by := b / (_bx * _bz)
	var x0 := bx * BLOCK
	var y0 := by * BLOCK
	var z0 := bz * BLOCK
	var vs := Vector3(voxel_size, voxel_size, voxel_size)
	for y in range(y0, mini(y0 + BLOCK, _ny)):
		for z in range(z0, mini(z0 + BLOCK, _nz)):
			for x in range(x0, mini(x0 + BLOCK, _nx)):
				var idx := _index(x, y, z)
				if _mana[idx] <= 0.0:
					continue
				var vmin := map_origin + Vector3(x, y, z) * voxel_size
				var d2 := _box_d2(p, vmin, vmin + vs)
				if d2 < _s_d2:
					_s_d2 = d2
					_s_best = idx


## Squared distance from a point to an axis-aligned box.
func _box_d2(p: Vector3, mn: Vector3, mx: Vector3) -> float:
	var dx := maxf(maxf(mn.x - p.x, 0.0), p.x - mx.x)
	var dy := maxf(maxf(mn.y - p.y, 0.0), p.y - mx.y)
	var dz := maxf(maxf(mn.z - p.z, 0.0), p.z - mx.z)
	return dx * dx + dy * dy + dz * dz


# --- Sources / inflow -------------------------------------------------------------

func _find_source(source: Node3D) -> Dictionary:
	for s in _sources:
		if s["source"] == source:
			return s
	return {}


func _update_sources() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var i := _sources.size() - 1
	while i >= 0:
		var s := _sources[i]
		var src: Object = s["source"]
		var casting: bool = is_instance_valid(src) and src.has_method("is_casting") and src.is_casting()
		var since_draw := now - float(s["last_draw"])
		var inflow := s["inflow"] as GPUParticles3D

		# Done with this spell once it was released (or freed) and its motes have faded.
		if not casting and since_draw > 1.2:
			inflow.queue_free()
			_sources.remove_at(i)
			i -= 1
			continue

		# Motes stream from the voxel being drained toward the spell.
		var from: Vector3 = s["from"]
		inflow.global_position = from
		if is_instance_valid(src):
			var to := (src as Node3D).global_position
			var dist := from.distance_to(to)
			if dist > 0.01:
				var pm := inflow.process_material as ParticleProcessMaterial
				pm.direction = (to - from) / dist
				var v := dist / inflow_lifetime
				pm.initial_velocity_min = v * 0.9
				pm.initial_velocity_max = v * 1.1
		inflow.emitting = since_draw < 0.12
		i -= 1


# --- Setup ------------------------------------------------------------------------

func _build_fade_ramp() -> void:
	# Fade in and out over each mote's life so they never pop.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
	])
	_fade_ramp = GradientTexture1D.new()
	_fade_ramp.gradient = gradient


func _read_region_from_floor() -> void:
	if _floor_mesh == null or _floor_mesh.mesh == null:
		return
	var bounds: AABB = _floor_mesh.global_transform * _floor_mesh.get_aabb()
	var center := bounds.get_center()
	region_center = Vector2(center.x, center.z)
	region_half = Vector2(bounds.size.x, bounds.size.z) * 0.5
	floor_y = bounds.end.y
	# The voxel grid covers the whole floor, from the floor up to the ether height.
	map_origin = Vector3(region_center.x - region_half.x, floor_y, region_center.y - region_half.y)
	map_size = Vector3(region_half.x * 2.0, ether_height, region_half.y * 2.0)

	# Keep only one half of the floor as the ether region.
	match ether_half:
		EtherHalf.POS_X:
			region_half.x *= 0.5
			region_center.x += region_half.x
		EtherHalf.NEG_X:
			region_half.x *= 0.5
			region_center.x -= region_half.x
		EtherHalf.POS_Z:
			region_half.y *= 0.5
			region_center.y += region_half.y
		EtherHalf.NEG_Z:
			region_half.y *= 0.5
			region_center.y -= region_half.y


func _setup_air() -> void:
	if _env == null:
		return
	_base_ambient_color = _env.ambient_light_color
	_base_ambient_energy = _env.ambient_light_energy
	_base_fog_color = _env.background_color
	_env.fog_enabled = true
	_env.fog_sky_affect = air_fog_sky_affect
	_env.fog_density = 0.0
	_env.fog_light_color = _base_fog_color


func _setup_motes() -> void:
	if not show_motes:
		return

	_mote_mat = ShaderMaterial.new()
	_mote_mat.shader = load("res://shaders/ether_mote.gdshader")
	_mote_mat.set_shader_parameter("mote_color", ether_color)
	_mote_mat.set_shader_parameter("intensity", mote_intensity)
	_mote_mat.set_shader_parameter("apply_region", true)
	_mote_mat.set_shader_parameter("ether_map", _texture)
	_mote_mat.set_shader_parameter("map_origin", map_origin)
	_mote_mat.set_shader_parameter("map_size", map_size)
	_mote_mat.set_shader_parameter("fade_start", mote_fade_start)
	_mote_mat.set_shader_parameter("fade_end", mote_fade_end)
	_mote_mat.set_shader_parameter("far_scale", mote_far_scale)

	var quad := QuadMesh.new()
	quad.size = Vector2(mote_size, mote_size)
	quad.material = _mote_mat

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = mote_area
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = mote_speed_min
	process.initial_velocity_max = mote_speed_max
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.5
	process.color_ramp = _fade_ramp

	_motes = GPUParticles3D.new()
	_motes.name = "EtherMotes"
	_motes.amount = mote_count
	_motes.lifetime = mote_lifetime
	_motes.preprocess = mote_lifetime
	# Motes stay where they spawn in the world while the emitter follows the player.
	_motes.local_coords = false
	_motes.process_material = process
	_motes.draw_pass_1 = quad
	_motes.visibility_aabb = AABB(-mote_area - Vector3.ONE * 4.0, (mote_area + Vector3.ONE * 4.0) * 2.0)
	add_child(_motes)


func _setup_bars() -> void:
	if not show_bars:
		return

	_bars_mat = ShaderMaterial.new()
	_bars_mat.shader = load("res://shaders/ether_voxels.gdshader")
	_bars_mat.set_shader_parameter("bar_color", ether_color)
	_bars_mat.set_shader_parameter("ether_map", _texture)
	_bars_mat.set_shader_parameter("map_origin", map_origin)
	_bars_mat.set_shader_parameter("map_size", map_size)
	_bars_mat.set_shader_parameter("voxel_size", voxel_size)
	_bars_mat.set_shader_parameter("view_radius", bar_view_radius)
	_bars_mat.set_shader_parameter("face_alpha", bar_face_alpha)
	_bars_mat.set_shader_parameter("edge_alpha", bar_edge_alpha)
	_bars_mat.set_shader_parameter("edge_width", bar_edge_width)
	_bars_mat.set_shader_parameter("near_fade_start", bar_near_fade_start)
	_bars_mat.set_shader_parameter("near_fade_end", bar_near_fade_end)

	# One unit cube per voxel in a window around the player. The shader reads each voxel's
	# ether from the 3D texture and sets the bar's height, so nothing updates on the CPU.
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	cube.material = _bars_mat

	_bar_half_x = maxi(ceili(bar_view_radius / voxel_size), 1)
	_bar_half_z = _bar_half_x
	var cells_x := _bar_half_x * 2
	var cells_z := _bar_half_z * 2

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = cube
	multi.instance_count = cells_x * _ny * cells_z
	var i := 0
	for y in _ny:
		for z in cells_z:
			for x in cells_x:
				var offset := Vector3(x - _bar_half_x, y, z - _bar_half_z) * voxel_size
				multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, offset))
				i += 1
	multi.custom_aabb = AABB(
			Vector3(-_bar_half_x, 0.0, -_bar_half_z) * voxel_size,
			Vector3(cells_x, _ny, cells_z) * voxel_size)

	_bars = MultiMeshInstance3D.new()
	_bars.name = "EtherBars"
	_bars.multimesh = multi
	_bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bars)
	_update_bars()


## Keeps the bar window centred on the player, snapped to the voxel grid.
func _update_bars() -> void:
	if _bars == null or _player == null:
		return
	var p := _player.global_position
	var snapped_x := map_origin.x + floorf((p.x - map_origin.x) / voxel_size) * voxel_size
	var snapped_z := map_origin.z + floorf((p.z - map_origin.z) / voxel_size) * voxel_size
	_bars.global_position = Vector3(snapped_x, map_origin.y, snapped_z)
	_bars_mat.set_shader_parameter("view_center", p)


func _setup_inflow_material() -> void:
	# Glowing motes that fly from the drained voxel to the spell.
	_inflow_mat = ShaderMaterial.new()
	_inflow_mat.shader = load("res://shaders/ether_mote.gdshader")
	_inflow_mat.set_shader_parameter("mote_color", ether_color)
	_inflow_mat.set_shader_parameter("intensity", inflow_intensity)
	_inflow_mat.set_shader_parameter("apply_region", false)
	_inflow_mat.set_shader_parameter("far_scale", 1.0)
	_inflow_mat.set_shader_parameter("fade_start", 200.0)
	_inflow_mat.set_shader_parameter("fade_end", 300.0)


## Motes that fly from the drained voxel to the spell while it draws ether.
func _make_inflow() -> GPUParticles3D:
	if _inflow_mat == null:
		_setup_inflow_material()

	var quad := QuadMesh.new()
	quad.size = Vector2(inflow_size, inflow_size)
	quad.material = _inflow_mat

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Start anywhere inside the voxel being drained.
	process.emission_box_extents = Vector3.ONE * voxel_size * 0.5
	process.direction = Vector3.UP
	process.spread = 3.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 1.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.color_ramp = _fade_ramp

	var inflow := GPUParticles3D.new()
	inflow.name = "EtherInflow"
	inflow.amount = inflow_count
	inflow.lifetime = inflow_lifetime
	# World space: motes keep flying toward the spell while the emitter hops voxels.
	inflow.local_coords = false
	inflow.emitting = false
	inflow.process_material = process
	inflow.draw_pass_1 = quad
	inflow.visibility_aabb = AABB(Vector3.ONE * -80.0, Vector3.ONE * 160.0)
	add_child(inflow)
	return inflow
