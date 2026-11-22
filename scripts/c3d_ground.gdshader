shader_type spatial;
// Ara sahne zemini: gürültüden yükselti (tepeler, dağlar, kumullar), yükseklik ve eğime göre renk,
// su seviyesinin altı dalgalı deniz, isteğe bağlı lav çatlakları (ışıyan)
uniform sampler2D hmap : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail : repeat_enable, filter_linear_mipmap;
uniform float amp = 120.0;          // yükselti
uniform float scale = 0.00035;      // gürültü ölçeği
uniform float ridge = 0.0;          // 1: sivri sırtlar (dağ), 0: yumuşak (tepe / kumul)
uniform vec3 low_col : source_color = vec3(0.25, 0.32, 0.18);
uniform vec3 mid_col : source_color = vec3(0.42, 0.36, 0.28);
uniform vec3 high_col : source_color = vec3(0.92, 0.94, 0.98);
uniform float snow_line = 0.75;     // 0..1 yükseklik oranı
uniform float water = -1.0;         // su seviyesi (yükselti oranı); <0 su yok
uniform vec3 water_col : source_color = vec3(0.04, 0.16, 0.24);
uniform float lava = 0.0;           // lav çatlakları
uniform vec3 lava_col : source_color = vec3(3.0, 0.8, 0.15);
uniform float dunes = 0.0;          // kum dalgacıkları
varying float hn;
varying vec3 wpos;

float hgt(vec2 p) {
	float n = texture(hmap, p * scale).r;
	float r = 1.0 - abs(n * 2.0 - 1.0);
	float h = mix(n, r * r, ridge);
	h += (texture(hmap, p * scale * 4.3 + 0.37).r - 0.5) * 0.18;
	h += dunes * sin(p.x * 0.012 + texture(hmap, p * scale * 2.0).r * 6.0) * 0.06;
	return h;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = hgt(w.xz);
	hn = h;
	float y = h * amp;
	if (water >= 0.0 && h < water) y = water * amp + sin(w.x * 0.02 + TIME * 1.2) * 1.5 + cos(w.z * 0.017 + TIME) * 1.5;
	VERTEX.y += y;
	float e = 6.0;
	float hx = hgt(w.xz + vec2(e, 0.0)) * amp, hz = hgt(w.xz + vec2(0.0, e)) * amp;
	NORMAL = normalize(vec3(h * amp - hx, e, h * amp - hz));
	if (water >= 0.0 && h < water) NORMAL = normalize(vec3(sin(w.x * 0.02 + TIME * 1.2) * 0.04, 1.0, cos(w.z * 0.017 + TIME) * 0.04)); // su: neredeyse düz, yumuşak dalga
	wpos = w;
}

void fragment() {
	// piksel başına normal (v0.13): kaba ızgaranın üçgen yüzeyleri görünmesin (tepeden bakışta keskin "buz kristali" deseni)
	vec3 nw = vec3(0.0, 1.0, 0.0);
	if (!(water >= 0.0 && hn < water)) {
		float e = 4.0, h0 = hgt(wpos.xz) * amp;
		nw = normalize(vec3(h0 - hgt(wpos.xz + vec2(e, 0.0)) * amp, e, h0 - hgt(wpos.xz + vec2(0.0, e)) * amp));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	float slope = 1.0 - nw.y;
	vec3 c = mix(low_col, mid_col, smoothstep(0.25, 0.6, hn));
	c = mix(c, mid_col * 0.8, smoothstep(0.25, 0.6, slope)); // dik yamaçlar kaya
	c = mix(c, high_col, smoothstep(snow_line - 0.06, snow_line + 0.04, hn) * (1.0 - smoothstep(0.4, 0.7, slope)));
	float dt = texture(detail, wpos.xz * 0.004).r;
	c *= 0.8 + 0.4 * dt;
	ROUGHNESS = 0.9;
	if (water >= 0.0 && hn < water) {
		float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		c = mix(water_col, vec3(0.6, 0.75, 0.85), f * 0.6);
		c += vec3(0.5) * smoothstep(water - 0.006, water, hn) * 0.4; // ince kıyı köpüğü
		ROUGHNESS = 0.4; SPECULAR = 0.25; // yumuşak yansıma (sert beyaz parlamalar göz yormasın)
	}
	if (lava > 0.0) {
		float k = smoothstep(0.47, 0.5, texture(detail, wpos.xz * 0.0016 + vec2(TIME * 0.004, 0.0)).r) * smoothstep(0.5, 0.2, hn);
		EMISSION = lava_col * k * lava * (0.7 + 0.3 * sin(TIME * 2.0 + wpos.x * 0.01));
		c = mix(c, vec3(0.05, 0.03, 0.03), 0.6 * lava);
	}
	ALBEDO = c;
}
