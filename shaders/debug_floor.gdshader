shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec3 color_a : source_color = vec3(0.12, 0.13, 0.15);
uniform vec3 color_b : source_color = vec3(0.2, 0.22, 0.26);
uniform vec3 line_color : source_color = vec3(0.35, 0.55, 0.7);
uniform float cell_size : hint_range(0.25, 4.0) = 1.0;
uniform float line_width : hint_range(0.01, 0.2) = 0.035;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = world_pos.xz / cell_size;
	vec2 cell = floor(grid);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 base = mix(color_a, color_b, checker);

	vec2 f = fract(grid);
	float line = step(f.x, line_width) + step(f.y, line_width)
			+ step(1.0 - line_width, f.x) + step(1.0 - line_width, f.y);
	line = clamp(line, 0.0, 1.0);

	ALBEDO = mix(base, line_color, line * 0.65);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
