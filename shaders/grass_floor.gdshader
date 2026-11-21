shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec3 grass_color : source_color = vec3(0.32, 0.52, 0.18);
uniform vec3 grass_color_dark : source_color = vec3(0.18, 0.34, 0.11);
uniform vec3 dry_tint : source_color = vec3(0.42, 0.38, 0.18);
uniform float scale : hint_range(0.5, 12.0) = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = world_pos.xz * scale;
	float n1 = noise(uv);
	float n2 = noise(uv * 3.7 + 12.3);
	float n3 = noise(uv * 14.0 + 4.2);
	float blade = mix(n1, n2, 0.55) * 0.8 + n3 * 0.2;

	vec3 grass = mix(grass_color_dark, grass_color, blade);
	float dry = smoothstep(0.58, 0.88, n1);
	ALBEDO = mix(grass, mix(grass, dry_tint, 0.45), dry * 0.35);
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
