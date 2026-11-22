shader_type canvas_item;
// Oyuncunun ÜSTÜNDEN geçen yarı saydam bulutlar (derinlik). Kameradan daha hızlı kayar (parallaks 1.3).
uniform vec2 cam = vec2(0.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float amount = 0.25;
uniform vec3 col = vec3(1.0);
uniform sampler2D ntex : repeat_enable, filter_linear_mipmap;

void fragment() {
	vec2 w = cam * 1.3 + (UV - 0.5) * view_size;
	float n = texture(ntex, w / 1900.0 + vec2(TIME * 0.006, 0.0)).r * 0.6 + texture(ntex, w / 760.0 + vec2(0.3, TIME * 0.004)).r * 0.4;
	float a = smoothstep(0.6, 0.82, n) * amount;
	COLOR = vec4(col * (0.85 + 0.15 * n), a);
}
