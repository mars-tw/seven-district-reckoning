shader_type spatial;
// Original glass UVs and geometry remain intact. Upper rooms reflect the street;
// they must not duplicate the ground-floor repair workshop.
uniform sampler2D window_texture : source_color, filter_linear_mipmap_anisotropic;
varying float height_in_world;
void vertex() { height_in_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
	vec3 workshop = texture(window_texture, UV).rgb;
	vec3 reflection = texture(window_texture, vec2(UV.x, 0.04 + UV.y * 0.17)).rgb;
	reflection = mix(reflection, vec3(0.11, 0.16, 0.20), 0.45);
	float upstairs = step(3.8, height_in_world);
	ALBEDO = mix(workshop, reflection, upstairs);
	ROUGHNESS = mix(0.70, 0.42, upstairs);
	METALLIC = 0.10;
}
