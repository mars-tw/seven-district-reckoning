shader_type spatial;
uniform sampler2D fabric_texture : source_color, filter_linear_mipmap_anisotropic;
varying vec3 tailoring_position;
void vertex() { tailoring_position = VERTEX; }
void fragment() {
	vec3 cloth = max(texture(fabric_texture,UV).rgb,vec3(0.055,0.085,0.15));
	float band = step(0.23,abs(tailoring_position.x))*step(1.18,tailoring_position.y)*(1.0-step(1.30,tailoring_position.y));
	ALBEDO = mix(cloth,vec3(0.95,0.62,0.035),band);
	ROUGHNESS = 0.88;
}
