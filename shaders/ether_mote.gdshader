shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform vec4 mote_color : source_color = vec4(0.62, 0.4, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.55;
// Ether voxels: 1 = full voxel, 0 = empty / drained. Layout is (x, z, y) in the texture.
// Motes dim with the ether left in their voxel and vanish when it is empty. Inflow motes
// (apply_region = false) ignore it.
uniform bool apply_region = true;
uniform sampler3D ether_map : filter_nearest, repeat_disable;
uniform vec3 map_origin = vec3(-30.0, -1.5, -30.0);
uniform vec3 map_size = vec3(60.0, 4.0, 60.0);
// Motes also fade with distance from the camera so they never pop in or out.
uniform float fade_start = 22.0;
uniform float fade_end = 32.0;
// Far motes are scaled up so they stay visible as distinct lights instead of 1px dots.
uniform float far_scale : hint_range(1.0, 6.0) = 1.0;

varying float visibility;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;

	float ether = 1.0;
	if (apply_region) {
		vec3 g = (center - map_origin) / map_size;
		float inside = step(0.0, min(min(g.x, g.y), g.z)) * step(max(max(g.x, g.y), g.z), 1.0);
		ether = textureLod(ether_map, vec3(g.x, g.z, g.y), 0.0).r * inside;
	}
	float dist = distance(center, CAMERA_POSITION_WORLD);
	visibility = ether * (1.0 - smoothstep(fade_start, fade_end, dist));

	// Camera-facing billboard, keeping the particle's scale.
	float s = length(MODEL_MATRIX[0].xyz) * mix(1.0, far_scale, smoothstep(0.0, fade_end, dist));
	mat4 world = mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	VERTEX *= s;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r2 = dot(uv, uv);
	float falloff = clamp(1.0 - r2, 0.0, 1.0);
	// Bright core plus a soft halo.
	float soft = pow(falloff, 3.0) + pow(falloff, 1.2) * 0.35;

	ALBEDO = mote_color.rgb * intensity;
	ALPHA = soft * COLOR.a * visibility;
}
