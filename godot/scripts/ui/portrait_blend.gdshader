shader_type canvas_item;
// Keep the generated real alpha; soften only the bottom of the knee-up cutout.
void fragment() {
	vec4 c = texture(TEXTURE,UV);
	c.rgb *= vec3(1.015,1.0,0.965);
	c.a *= 1.0-smoothstep(0.90,1.0,UV.y);
	COLOR = c;
}
