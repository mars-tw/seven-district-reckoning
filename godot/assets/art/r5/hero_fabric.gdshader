shader_type spatial;
// Bind-pose coordinates preserve markings through the original skeletal animation.
uniform sampler2D fabric_texture : source_color, filter_linear_mipmap_anisotropic;
varying vec3 cloth_position;
void vertex() {
	cloth_position = VERTEX;
	// The messenger bag already belongs to the real skinned mesh. Enlarge only
	// its bind-pose region, preserving the skeleton and every animation clip.
	float bag_vertex = step(0.11,VERTEX.x)*step(0.84,VERTEX.y)*(1.0-step(1.13,VERTEX.y))*step(-0.16,VERTEX.z)*(1.0-step(-0.045,VERTEX.z));
	VERTEX = mix(VERTEX,vec3(0.24,0.979,-0.10)+(VERTEX-vec3(0.24,0.979,-0.10))*vec3(1.35,1.25,1.35),bag_vertex);
}
void fragment() {
	vec3 fabric = max(texture(fabric_texture, UV).rgb, vec3(0.055, 0.085, 0.15));
	float band = step(0.23, abs(cloth_position.x)) * step(1.18, cloth_position.y) * (1.0-step(1.30, cloth_position.y));
	float bag = step(0.10, cloth_position.x) * step(-0.20, cloth_position.z) * (1.0-step(-0.025, cloth_position.z)) * step(0.78, cloth_position.y) * (1.0-step(1.13, cloth_position.y));
	ALBEDO = mix(fabric, vec3(1.0, 0.66, 0.02), band);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.36, 0.035), bag);
	ROUGHNESS = 0.88;
	RIM = 0.24;
	RIM_TINT = 0.25;
}
