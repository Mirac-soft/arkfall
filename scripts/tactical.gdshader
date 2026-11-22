shader_type canvas_item;
// Taktik savaş masası katmanı: turuncu koordinat ızgarası, aşağı süpüren radar bandı
uniform vec2 px_size = vec2(1280.0, 3000.0);
uniform vec3 col = vec3(1.0, 0.45, 0.12);

void fragment() {
	vec2 p = UV * px_size;
	vec2 g = abs(fract(p / 80.0) - 0.5);
	float grid = (1.0 - smoothstep(0.0, 0.012, min(g.x, g.y))) * 0.10;
	vec2 g2 = abs(fract(p / 400.0) - 0.5);
	grid += (1.0 - smoothstep(0.0, 0.004, min(g2.x, g2.y))) * 0.18;
	float sweep = smoothstep(260.0, 0.0, mod(p.y - TIME * 220.0, 1400.0)) * 0.10;
	COLOR = vec4(col, grid + sweep);
}
