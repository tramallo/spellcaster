extends Object
## Shapes a spell can take besides the default sphere.
##
## A shape is a convex polyhedron whose corners all lie on a sphere of radius 1 (the sphere it
## replaces), with its tip toward local forward (-Z). The spell's radius scales it, so a
## spell of radius r fits inside the sphere of radius r. The spell morphs from sphere to
## polyhedron by sliding every vertex of a finely divided mesh from the sphere onto the
## polyhedron's surface (the work is done by `mana_orb.gdshader`).

## How many times each face is divided per edge for the morph mesh (more = rounder sphere).
const SUBDIVISIONS := 20

const SQRT_8_9 := 0.9428090415820634  # radius of the pyramid's base corners (circumradius 1)
const INV_SQRT_3 := 0.5773502691896258  # half the cube's edge (circumradius 1)

static var _cache: Dictionary = {}


## Catalog data: "corners" and "faces" (corner indices) describe the polyhedron at radius 1;
## "back_extent" is how far behind the spell's centre its back face is (1 for the sphere).
static func _shape_data(shape_id: String) -> Dictionary:
	match shape_id:
		"pyramid":
			# Regular tetrahedron (3-sided pyramid): apex forward (-Z), triangular base behind,
			# one base corner pointing up.
			var corners := PackedVector3Array([
				Vector3(0.0, 0.0, -1.0),
				Vector3(0.0, SQRT_8_9, 1.0 / 3.0),
				Vector3(-SQRT_8_9 * 0.8660254037844386, -SQRT_8_9 * 0.5, 1.0 / 3.0),
				Vector3(SQRT_8_9 * 0.8660254037844386, -SQRT_8_9 * 0.5, 1.0 / 3.0),
			])
			return {
				"corners": corners,
				"faces": [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]],
				"back_extent": 1.0 / 3.0,
			}
		"cube":
			# Cube with a face toward the front (-Z). Corner i: x is + when bit 0 is set, y when
			# bit 1 is set, z when bit 2 is set. Each square face is two triangles; "hidden" says
			# which edge of each triangle is the diagonal (1: a-c, 2: a-b) so it is not drawn.
			var cube_corners := PackedVector3Array()
			for i in 8:
				cube_corners.append(Vector3(
						INV_SQRT_3 if (i & 1) != 0 else -INV_SQRT_3,
						INV_SQRT_3 if (i & 2) != 0 else -INV_SQRT_3,
						INV_SQRT_3 if (i & 4) != 0 else -INV_SQRT_3))
			var quads := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6]]
			var cube_faces := []
			var hidden := []
			for q in quads:
				cube_faces.append([q[0], q[1], q[2]])
				hidden.append(1)
				cube_faces.append([q[0], q[2], q[3]])
				hidden.append(2)
			return {
				"corners": cube_corners,
				"faces": cube_faces,
				"hidden": hidden,
				"back_extent": INV_SQRT_3,
			}
	return {}


static func has_shape(shape_id: String) -> bool:
	return not _shape_data(shape_id).is_empty()


## How far behind the spell's centre (in radii) the shape's rearmost point is.
static func back_extent(shape_id: String) -> float:
	var data := _shape_data(shape_id)
	return float(data.get("back_extent", 1.0))


## The shape's corners at radius 1 (for the collision shape).
static func corners(shape_id: String) -> PackedVector3Array:
	var data := _shape_data(shape_id)
	if data.is_empty():
		return PackedVector3Array()
	return data["corners"]


## Mesh with per-vertex data for the morph (built once per shape and shared):
##  - vertex / normal: the point on the unit sphere and its normal;
##  - uv (x, y) and uv2 (x): the matching point (x, y, z) on the polyhedron's surface;
##  - color (r, g): where the vertex sits inside its polyhedron face (for the edges);
##    color b: an edge of that face not to draw (a quad's diagonal), as quarters.
## (Plain UV channels are used because they work in every renderer; the shader works the face
## normals out itself.)
static func morph_mesh(shape_id: String) -> ArrayMesh:
	if _cache.has(shape_id):
		return _cache[shape_id]
	var data := _shape_data(shape_id)
	if data.is_empty():
		return null

	var corner_points: PackedVector3Array = data["corners"]
	var sphere_points := PackedVector3Array()
	var sphere_normals := PackedVector3Array()
	var flat_xy := PackedVector2Array()
	var flat_z := PackedVector2Array()
	var face_coords := PackedColorArray()

	var hidden_edges: Array = data.get("hidden", [])
	var face_index := -1
	for face in data["faces"]:
		face_index += 1
		var hidden_edge: int = hidden_edges[face_index] if face_index < hidden_edges.size() else 0
		var a: Vector3 = corner_points[face[0]]
		var b: Vector3 = corner_points[face[1]]
		var c: Vector3 = corner_points[face[2]]
		var outward := (b - a).cross(c - a).normalized()
		if outward.dot(a + b + c) < 0.0:
			outward = -outward
		var u := (b - a) / SUBDIVISIONS
		var v := (c - a) / SUBDIVISIONS
		for i in SUBDIVISIONS:
			for j in SUBDIVISIONS - i:
				# Triangle of the cell, then (when it fits) its mirror triangle.
				_add_triangle(a + u * i + v * j, a + u * (i + 1) + v * j, a + u * i + v * (j + 1),
						[a, b, c], outward, sphere_points, sphere_normals, flat_xy, flat_z, face_coords,
						hidden_edge)
				if i + j < SUBDIVISIONS - 1:
					_add_triangle(a + u * (i + 1) + v * j, a + u * i + v * (j + 1),
							a + u * (i + 1) + v * (j + 1),
							[a, b, c], outward, sphere_points, sphere_normals, flat_xy, flat_z, face_coords,
							hidden_edge)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sphere_points
	arrays[Mesh.ARRAY_NORMAL] = sphere_normals
	arrays[Mesh.ARRAY_TEX_UV] = flat_xy
	arrays[Mesh.ARRAY_TEX_UV2] = flat_z
	arrays[Mesh.ARRAY_COLOR] = face_coords
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[shape_id] = mesh
	return mesh


## Adds one triangle: its three points on the polyhedron (`p0..p2`), wound so it faces
## `outward`, together with the matching points on the unit sphere.
static func _add_triangle(p0: Vector3, p1: Vector3, p2: Vector3, face: Array, outward: Vector3,
		sphere_points: PackedVector3Array, sphere_normals: PackedVector3Array,
		flat_xy: PackedVector2Array, flat_z: PackedVector2Array,
		face_coords: PackedColorArray, hidden_edge: int) -> void:
	# Godot treats clockwise triangles (seen from outside) as front faces.
	if (p1 - p0).cross(p2 - p0).dot(outward) > 0.0:
		var swap := p1
		p1 = p2
		p2 = swap
	for p in [p0, p1, p2]:
		var direction: Vector3 = (p as Vector3).normalized()
		sphere_points.append(direction)
		sphere_normals.append(direction)
		flat_xy.append(Vector2(p.x, p.y))
		flat_z.append(Vector2(p.z, 0.0))
		# Position inside the polyhedron's face (barycentric s, t), so the shader can find its edges.
		var st := _face_coordinates(p, face[0], face[1], face[2])
		# Blue says which edge of the face the shader must not draw (0: none, 1: a-c, 2: a-b, 3: b-c).
		face_coords.append(Color(st.x, st.y, hidden_edge / 4.0, 1.0))


## Barycentric coordinates (s, t) of `p` on the triangle a, b, c: p = a + s (b - a) + t (c - a).
static func _face_coordinates(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector2:
	var e1 := b - a
	var e2 := c - a
	var d := p - a
	var d11 := e1.dot(e1)
	var d12 := e1.dot(e2)
	var d22 := e2.dot(e2)
	var denominator := d11 * d22 - d12 * d12
	return Vector2(
		(d22 * d.dot(e1) - d12 * d.dot(e2)) / denominator,
		(d11 * d.dot(e2) - d12 * d.dot(e1)) / denominator)
