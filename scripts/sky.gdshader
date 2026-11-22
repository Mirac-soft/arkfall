shader_type canvas_item;
// Sonsuz harita: her bölümün kendi zemini (biome). Gürültü tekrar eden dokulardan okunur.
// 0 deniz  1 askeri üs  2 kanyon  3 dağ  4 göl  5 kar  6 bulut  7 fırtına  8 kutup  9 çöl
// 10 lav  11 stratosfer  12 yörünge enkazı  13 Sefine gövdesi  14 harabe şehir
uniform vec2 cam = vec2(0.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform int biome = 0;
uniform float par = 0.6;
uniform vec3 tint = vec3(1.0);
uniform sampler2D ntex : repeat_enable, filter_linear_mipmap;
uniform sampler2D stex : repeat_enable, filter_linear;

float tx(vec2 w, float s) { return texture(ntex, w / s).r; }
float n2(vec2 w, float s) { return tx(w, s) * 0.62 + texture(ntex, w / (s * 0.37) + vec2(0.31, 0.77)).r * 0.38; }
float cell(vec2 w, float s) { return texture(stex, w / s).r; } // hücresel: noktaya uzaklık
float h1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 sea(vec2 w) {
	float n = n2(w, 2600.0);
	vec3 col = mix(vec3(0.02, 0.13, 0.22), vec3(0.06, 0.36, 0.45), smoothstep(0.4, 0.62, n));
	col += vec3(0.05) * smoothstep(0.55, 0.75, tx(w + vec2(TIME * 3.0, TIME * 2.0), 260.0));
	float shore = smoothstep(0.64, 0.655, n);
	vec3 land = mix(vec3(0.86, 0.78, 0.55), vec3(0.22, 0.46, 0.22), smoothstep(0.655, 0.675, n));
	land = mix(land, vec3(0.1, 0.28, 0.14), smoothstep(0.69, 0.76, n) * smoothstep(0.4, 0.62, tx(w, 500.0)));
	col = mix(col, vec3(0.1, 0.5, 0.52), smoothstep(0.6, 0.64, n) * (1.0 - shore) * 0.6);
	return mix(col, land, shore);
}
vec3 clouds(vec2 w) {
	float c = n2(w + vec2(TIME * 6.0, 0.0), 1500.0);
	vec3 col = mix(vec3(0.36, 0.44, 0.62), vec3(0.95, 0.97, 1.0), smoothstep(0.38, 0.68, c));
	return mix(col, vec3(0.7, 0.78, 0.94), 0.3 * tx(w, 300.0));
}
vec3 space(vec2 w) {
	vec3 col = vec3(0.01, 0.012, 0.035);
	col += vec3(0.28, 0.08, 0.38) * smoothstep(0.5, 0.8, n2(w, 3000.0)) * 0.7;
	col += vec3(0.04, 0.14, 0.32) * smoothstep(0.48, 0.78, n2(w + 900.0, 4200.0)) * 0.6;
	float s1 = smoothstep(0.04, 0.0, cell(w, 2300.0)) * step(0.45, tx(w, 61.0));
	float s2 = smoothstep(0.03, 0.0, cell(w + 400.0, 1300.0)) * step(0.55, tx(w, 43.0)) * 0.6;
	return col + vec3(0.9, 0.95, 1.0) * (s1 + s2);
}
vec3 base(vec2 w) { // askeri üs: çimen, beton pistler, hangar sıraları
	vec3 col = mix(vec3(0.17, 0.27, 0.15), vec3(0.24, 0.34, 0.18), n2(w, 900.0));
	col = mix(col, vec3(0.32, 0.28, 0.2), smoothstep(0.6, 0.7, tx(w, 400.0)) * 0.6);
	vec2 g = mod(w, vec2(1800.0, 1400.0));
	float run = step(g.y, 120.0) * step(100.0, g.x);
	col = mix(col, vec3(0.2, 0.21, 0.23), run);
	col = mix(col, vec3(0.85), run * step(abs(g.y - 60.0), 3.0) * step(0.5, fract(w.x / 80.0)));
	float tax = step(abs(g.x - 900.0), 22.0);
	col = mix(col, vec3(0.25, 0.26, 0.28), tax);
	vec2 hc = floor(w / vec2(1800.0, 1400.0));
	vec2 hl = g - vec2(200.0 + h1(hc) * 900.0, 300.0);
	float hang = step(0.0, hl.x) * step(hl.x, 260.0) * step(0.0, hl.y) * step(hl.y, 160.0);
	col = mix(col, vec3(0.42, 0.44, 0.48) * (0.85 + 0.15 * step(0.5, fract(hl.x / 26.0))), hang);
	return col;
}
vec3 canyon(vec2 w) { // Kapadokya: turuncu kaya, yarıklar, peribacaları
	float n = n2(w, 1400.0);
	vec3 col = mix(vec3(0.62, 0.38, 0.22), vec3(0.86, 0.66, 0.44), n);
	col *= 0.8 + 0.25 * smoothstep(0.3, 0.7, tx(w, 220.0));
	float crev = 1.0 - smoothstep(0.0, 0.025, abs(tx(w, 900.0) - 0.5));
	col = mix(col, vec3(0.25, 0.13, 0.08), crev * 0.85);
	float ch = smoothstep(0.08, 0.0, cell(w, 3200.0));
	col = mix(col, vec3(0.95, 0.85, 0.7), ch);
	col = mix(col, vec3(0.35, 0.2, 0.12), smoothstep(0.1, 0.13, cell(w, 3200.0)) * smoothstep(0.17, 0.13, cell(w, 3200.0)) * 0.6);
	return col;
}
vec3 mountain(vec2 w, float snow) { // orman vadileri, kaya, kar
	float h = n2(w, 1800.0);
	vec3 col = mix(vec3(0.12, 0.3, 0.14), vec3(0.2, 0.4, 0.18), tx(w, 300.0));
	col = mix(col, vec3(0.42, 0.4, 0.36), smoothstep(0.55, 0.65, h));
	col = mix(col, vec3(0.92, 0.94, 0.98), smoothstep(0.7 - snow, 0.74 - snow, h));
	col *= 0.85 + 0.3 * (tx(w + vec2(30.0), 600.0) - tx(w, 600.0)) * 6.0 + 0.1;
	return col;
}
vec3 lake(vec2 w) {
	float n = n2(w, 2400.0);
	vec3 col = mountain(w, -0.05);
	vec3 water = mix(vec3(0.08, 0.3, 0.45), vec3(0.14, 0.45, 0.55), tx(w + TIME * 4.0, 300.0));
	col = mix(col, vec3(0.8, 0.75, 0.6), smoothstep(0.5, 0.52, 1.0 - n) * 0.8);
	return mix(col, water, smoothstep(0.52, 0.535, 1.0 - n));
}
vec3 snowf(vec2 w) {
	vec3 col = mix(vec3(0.82, 0.86, 0.94), vec3(0.98, 0.99, 1.0), n2(w, 1200.0));
	col = mix(col, vec3(0.35, 0.36, 0.4), smoothstep(0.72, 0.78, n2(w + 300.0, 900.0)));
	float crev = 1.0 - smoothstep(0.0, 0.015, abs(tx(w, 700.0) - 0.5));
	return mix(col, vec3(0.45, 0.6, 0.78), crev * 0.7);
}
vec3 storm(vec2 w) {
	vec3 col = clouds(w) * vec3(0.42, 0.46, 0.58);
	float fl = step(0.93, h1(vec2(floor(TIME * 1.5), 1.0))) * (1.0 - fract(TIME * 1.5));
	col += vec3(0.6, 0.65, 0.9) * fl * smoothstep(0.4, 0.7, tx(w, 900.0));
	return col;
}
vec3 arctic(vec2 w) {
	float c = cell(w, 2600.0);
	vec3 sea2 = mix(vec3(0.02, 0.06, 0.12), vec3(0.04, 0.12, 0.2), tx(w, 500.0));
	vec3 ice = mix(vec3(0.82, 0.9, 0.96), vec3(0.95, 0.98, 1.0), tx(w, 200.0));
	return mix(sea2, ice, smoothstep(0.045, 0.06, c) * smoothstep(0.55, 0.45, tx(w, 3000.0) * 0.6 + c * 0.6));
}
vec3 desert(vec2 w) {
	float d = sin(w.y / 70.0 + tx(w, 900.0) * 12.0 + w.x / 400.0);
	vec3 col = mix(vec3(0.78, 0.6, 0.36), vec3(0.95, 0.8, 0.52), d * 0.5 + 0.5);
	col *= 0.85 + 0.2 * n2(w, 1600.0);
	return mix(col, vec3(0.55, 0.42, 0.28), smoothstep(0.7, 0.75, n2(w, 2600.0)) * 0.7);
}
vec3 lava(vec2 w) {
	float n = tx(w, 800.0);
	vec3 col = mix(vec3(0.08, 0.06, 0.06), vec3(0.2, 0.16, 0.15), tx(w, 200.0));
	float crack = (1.0 - smoothstep(0.0, 0.03, abs(n - 0.5))) * smoothstep(0.42, 0.62, tx(w + 700.0, 1500.0)); // parçalı lav akıntıları
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + w.x * 0.01);
	col += vec3(1.6, 0.5, 0.1) * crack * pulse;
	col = mix(col, vec3(1.3, 0.45, 0.08) * pulse, smoothstep(0.72, 0.76, n2(w, 2000.0)));
	return col;
}
vec3 strato(vec2 w) { return mix(clouds(w * 0.6) * 0.75, vec3(0.04, 0.08, 0.22), 0.45); }
vec3 debris(vec2 w) {
	vec3 col = space(w);
	float d = smoothstep(0.06, 0.03, cell(w + vec2(TIME * 8.0, 0.0), 1600.0));
	return mix(col, vec3(0.42, 0.42, 0.48) * (0.6 + 0.4 * tx(w, 40.0)), d);
}
vec3 hull(vec2 w) { // Sefine gövdesi: altıgen plakalar, parlayan derzler
	vec2 p = w / 90.0;
	vec2 r = vec2(1.0, 1.732);
	vec2 a = mod(p, r) - r * 0.5;
	vec2 b = mod(p - r * 0.5, r) - r * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = p - g;
	float edge = 0.5 - max(abs(g.x) * 0.866 + abs(g.y) * 0.5, abs(g.y));
	vec3 col = mix(vec3(0.62, 0.6, 0.55), vec3(0.85, 0.82, 0.74), h1(floor(id * 2.0)));
	col *= 0.8 + 0.3 * tx(w, 500.0);
	col = mix(col, vec3(0.9, 0.5, 1.6) * (0.7 + 0.3 * sin(TIME * 3.0 + id.x)), 1.0 - smoothstep(0.0, 0.05, edge));
	return col;
}
vec3 ruins(vec2 w) { // harabe şehir: sokak ızgarası, yıkık binalar, yangınlar
	vec2 c = floor(w / 160.0);
	vec2 f = mod(w, 160.0);
	vec3 col = vec3(0.16, 0.15, 0.15) + 0.04 * tx(w, 90.0);
	float bld = step(22.0, f.x) * step(f.x, 138.0) * step(22.0, f.y) * step(f.y, 138.0);
	float broken = step(0.55, h1(c));
	vec3 roof = mix(vec3(0.34, 0.33, 0.32), vec3(0.5, 0.47, 0.44), h1(c + 3.0));
	roof *= 0.85 + 0.15 * step(0.5, fract(f.x / 14.0));
	vec3 rubble = mix(vec3(0.2, 0.18, 0.16), vec3(0.4, 0.36, 0.32), tx(w, 30.0));
	col = mix(col, mix(roof, rubble, broken), bld);
	col = mix(col, col * 0.55, step(138.0, f.x + 10.0) * bld); // gölge
	float fire = broken * smoothstep(0.65, 0.8, tx(w + vec2(0.0, TIME * 20.0), 70.0)) * bld;
	col += vec3(1.8, 0.6, 0.15) * fire;
	return col;
}

void fragment() {
	vec2 w = cam * par + (UV - 0.5) * view_size;
	vec3 col;
	if (biome == 0) col = sea(w);
	else if (biome == 1) col = base(w);
	else if (biome == 2) col = canyon(w);
	else if (biome == 3) col = mountain(w, 0.0);
	else if (biome == 4) col = lake(w);
	else if (biome == 5) col = snowf(w);
	else if (biome == 6) col = clouds(w * 1.1);
	else if (biome == 7) col = storm(w * 1.1);
	else if (biome == 8) col = arctic(w);
	else if (biome == 9) col = desert(w);
	else if (biome == 10) col = lava(w);
	else if (biome == 11) col = strato(w);
	else if (biome == 12) col = debris(w);
	else if (biome == 13) col = hull(w);
	else col = ruins(w);
	// alçak bulutlar (yerdeki haritalarda derinlik hissi)
	if (biome <= 5 || biome >= 8 && biome <= 10 || biome == 14) {
		vec2 w2 = cam * (par + 0.3) + (UV - 0.5) * view_size;
		float ca = smoothstep(0.6, 0.78, n2(w2 + vec2(TIME * 10.0, 0.0), 1200.0)) * (biome == 14 ? 0.35 : 0.55);
		col = mix(col, biome == 14 || biome == 10 ? vec3(0.25, 0.22, 0.22) : vec3(0.95, 0.97, 1.0), ca);
	}
	col *= tint;
	vec2 d = UV - 0.5;
	col *= 1.0 - dot(d, d) * 0.6;
	COLOR = vec4(col, 1.0);
}
