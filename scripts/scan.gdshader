shader_type canvas_item;
// Endüstriyel ekran dokusu: tarama çizgileri, aşağı kayan parlak bant, köşe karartma
uniform float lines = 0.08;
uniform vec3 glow = vec3(1.0, 0.42, 0.1);

void fragment() {
	vec2 uv = SCREEN_UV;
	float scan = step(0.5, fract(FRAGCOORD.y / 3.0)) * lines;
	float band = smoothstep(0.03, 0.0, abs(fract(uv.y - TIME * 0.07) - 0.5)) * 0.05;
	vec2 d = uv - 0.5;
	float vig = smoothstep(0.25, 0.85, dot(d, d) * 2.2) * 0.65;
	float a = max(scan, vig);
	COLOR = vec4(mix(vec3(0.0), glow, band / max(a + band, 0.001)), clamp(a + band, 0.0, 1.0));
}
