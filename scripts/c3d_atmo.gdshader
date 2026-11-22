shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;
// Atmosfer halesi: kenarlarda parlayan mavi kabuk
uniform vec3 col : source_color = vec3(0.3, 0.6, 1.0);
uniform float power = 3.0;
uniform float strength = 1.6;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), power);
	ALBEDO = col * f * strength;
}
