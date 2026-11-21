shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

// Each ether voxel is drawn as a see-through violet cube whose height is its ether amount:
// a full voxel is a whole cube, a drained one shrinks like a 3D bar until it is flat (hidden).
// The instance's translation is the voxel's minimum corner; the amount comes from the
// ether voxel texture (x, z, y layout, R = fill 0..1).

uniform vec4 bar_color : source_color = vec4(0.62, 0.4, 1.0, 1.0);
uniform float face_alpha : hint_range(0.0, 1.0) = 0.14;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float edge_width = 0.02;

uniform sampler3D ether_map : filter_nearest, repeat_disable;
uniform vec3 map_origin = vec3(-30.0, -1.5, -30.0);
uniform vec3 map_size = vec3(60.0, 4.0, 60.0);
uniform float voxel_size = 0.5;

// Bars fade out toward the edge of the window around the player...
uniform vec3 view_center = vec3(0.0);
uniform float view_radius = 10.0;
// ...and close to the camera, so they never block the view.
uniform float near_fade_start = 0.7;
uniform float near_fade_end = 2.5;

varying vec3 bar_pos;
varying vec3 bar_size;
varying float fade;

void vertex() {
	vec3 corner = MODEL_MATRIX[3].xyz;
	vec3 center = corner + vec3(0.5 * voxel_size);

	vec3 g = (center - map_origin) / map_size;
	float inside = step(0.0, min(min(g.x, g.y), g.z)) * step(max(max(g.x, g.y), g.z), 1.0);
	float fill = textureLod(ether_map, vec3(g.x, g.z, g.y), 0.0).r * inside;

	float horizontal = distance(center.xz, view_center.xz);
	fade = (1.0 - smoothstep(view_radius * 0.7, view_radius, horizontal))
			* smoothstep(near_fade_start, near_fade_end, distance(center, CAMERA_POSITION_WORLD));

	// Unit cube (-0.5..0.5) -> bar with its base on the bottom of the voxel; a small gap
	// between neighbouring cubes keeps the edges readable.
	float gap = 0.01;
	vec3 local = VERTEX + vec3(0.5);
	vec3 size = vec3(voxel_size - 2.0 * gap, voxel_size * fill, voxel_size - 2.0 * gap);
	bar_size = size;
	bar_pos = local * size;
	VERTEX = vec3(gap, 0.0, gap) + bar_pos;

	// Drained (or outside the ether): collapse the cube to nothing.
	if (fill < 0.002) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// Edge lines: points within edge_width of the cube's boundary along two axes at once.
	vec3 d = min(bar_pos, bar_size - bar_pos);
	float near_count = step(d.x, edge_width) + step(d.y, edge_width) + step(d.z, edge_width);
	float edge = step(2.0, near_count);

	ALBEDO = bar_color.rgb;
	ALPHA = mix(face_alpha, edge_alpha, edge) * fade;
}
