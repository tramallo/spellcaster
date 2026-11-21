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
// 1 = natural size for current mana; higher = compressed / denser / brighter.
uniform float density_factor : hint_range(0.25, 40.0) = 1.0;

// Shape morph (see ShapeCatalog): the mesh holds unit-sphere points in VERTEX and the matching
// points of the target polyhedron in UV (x, y) and UV2 (x = z). 0 = sphere, 1 = polyhedron.
uniform bool morph_enabled = false;
uniform float shape_morph : hint_range(0.0, 1.0) = 0.0;
// Radius of the spell: the morph mesh is a unit mesh and is scaled by this.
uniform float shape_scale = 1.0;
// Flat-sided shapes have no rim to fade in at, so they get a base opacity and glowing edges.
uniform float face_fill : hint_range(0.0, 1.0) = 0.3;
uniform float edge_width : hint_range(0.0, 0.2) = 0.03;
uniform float edge_glow : hint_range(0.0, 4.0) = 1.4;

varying float wave_amount;
// Position inside the polyhedron face the vertex belongs to (barycentric), for the edges.
varying vec2 face_st;

void vertex() {
	float t = TIME * wave_speed;
	vec3 n = normalize(NORMAL);
	if (morph_enabled) {
		VERTEX = mix(VERTEX, vec3(UV, UV2.x), shape_morph) * shape_scale;
		face_st = COLOR.rg;
	}

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
	vec3 normal = normalize(NORMAL);
	if (morph_enabled) {
		// Flat faces: the face normal from the screen-space slope of the surface, blended in
		// with the morph (the mesh only carries sphere normals).
		vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(face_normal, VIEW) < 0.0) {
			face_normal = -face_normal;
		}
		normal = normalize(mix(normal, face_normal, shape_morph));
	}
	float ndotv = clamp(dot(normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);

	float ripple = 0.5 + 0.5 * wave_amount;
	float body = mix(interior_darken, 1.0, fresnel);
	// Closeness to the nearest edge of the polyhedron face (1 on the edge, 0 away from it).
	float edge = 0.0;
	if (morph_enabled) {
		float nearest = min(min(face_st.x, face_st.y), 1.0 - face_st.x - face_st.y);
		edge = (1.0 - smoothstep(0.0, edge_width, nearest)) * shape_morph;
	}
	float density_glow = clamp(density_factor, 0.25, 40.0);
	vec3 color = mana_color.rgb * mix(0.75, 1.2, ripple) * body * mix(1.0, 1.35, clamp(density_glow - 1.0, 0.0, 3.0) / 3.0);

	// Soft volumetric read: denser center, brighter rim
	float alpha = mix(mana_color.a * 0.35, min(mana_color.a + 0.35, 0.92), fresnel);
	alpha = clamp(alpha + abs(wave_amount) * 0.12 + (density_glow - 1.0) * 0.04, 0.12, 0.98);
	if (morph_enabled) {
		alpha = clamp(max(alpha, face_fill * shape_morph) + edge * 0.45, 0.12, 0.98);
	}

	ALBEDO = color;
	EMISSION = glow_color.rgb * (0.25 + fresnel * emission_strength + abs(wave_amount) * 0.45) * density_glow;
	EMISSION += glow_color.rgb * edge * edge_glow;
	ROUGHNESS = mix(0.35, 0.08, fresnel);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = alpha;
	RIM = 0.85;
	RIM_TINT = 0.35;
}
