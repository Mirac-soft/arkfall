shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Yumuşak bulut kümesi: kameraya dönük kare, gürültülü yumuşak kenar, güneş tarafı daha aydınlık
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 lit : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 shade : source_color = vec3(0.55, 0.6, 0.7);
uniform float alpha = 0.85;
uniform float seed = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv * vec2(1.0, 1.6));
	float n = texture(noise, UV * 0.9 + seed + TIME * 0.004).r * 0.65 + texture(noise, UV * 2.3 - seed * 0.5).r * 0.35;
	float a = smoothstep(1.0, 0.25, r + (0.55 - n) * 0.9);
	ALBEDO = mix(shade, lit, clamp(0.5 - uv.y * 0.6 + n * 0.4, 0.0, 1.0));
	ALPHA = a * alpha;
}
