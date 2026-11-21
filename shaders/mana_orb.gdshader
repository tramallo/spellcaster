shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 mana_color : source_color = vec4(0.42, 0.78, 1.0, 0.5);
uniform vec4 glow_color : source_color = vec4(0.55, 0.88, 1.0, 1.0);
uniform float wave_strength : hint_range(0.0, 0.2) = 0.045;
uniform float wave_speed : hint_range(0.0, 6.0) = 1.6;
uniform float wave_frequency : hint_range(1.0, 16.0) = 6.0;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.4;
uniform float emission_strength : hint_range(0.0, 6.0) = 2.0;
uniform float interior_darken : hint_range(0.0, 1.0) = 0.55;

varying float wave_amount;

void vertex() {
	float t = TIME * wave_speed;
	vec3 n = normalize(NORMAL);

	float w1 = sin(VERTEX.x * wave_frequency + t)
			* cos(VERTEX.y * wave_frequency * 0.85 - t * 0.7);
	float w2 = sin(VERTEX.y * wave_frequency * 1.25 + t * 1.15)
			* cos(VERTEX.z * wave_frequency * 0.95 + t * 0.55);
	float w3 = sin(VERTEX.z * wave_frequency * 0.75 - t * 0.95 + VERTEX.x * 2.2);

	wave_amount = (w1 + w2 + w3) * (1.0 / 3.0);
	VERTEX += n * wave_amount * wave_strength;

	vec3 bump = vec3(w1, w2, w3) * wave_strength * 3.5;
	NORMAL = normalize(n + bump);
}

void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);

	float ripple = 0.5 + 0.5 * wave_amount;
	float body = mix(interior_darken, 1.0, fresnel);
	vec3 color = mana_color.rgb * mix(0.75, 1.2, ripple) * body;

	// Soft volumetric read: denser center, brighter rim
	float alpha = mix(mana_color.a * 0.35, min(mana_color.a + 0.35, 0.92), fresnel);
	alpha = clamp(alpha + abs(wave_amount) * 0.12, 0.12, 0.95);

	ALBEDO = color;
	EMISSION = glow_color.rgb * (0.25 + fresnel * emission_strength + abs(wave_amount) * 0.45);
	ROUGHNESS = mix(0.35, 0.08, fresnel);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = alpha;
	RIM = 0.85;
	RIM_TINT = 0.35;
}
