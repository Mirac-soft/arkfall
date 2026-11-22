shader_type spatial;
// Dünya: gürültüden kıtalar (yeşil-kahve), okyanus, dönen bulut katmanı, gece tarafında şehir ışıkları
uniform sampler2D land : repeat_enable, filter_linear_mipmap;
uniform sampler2D clouds : repeat_enable, filter_linear_mipmap;
uniform vec3 sun_dir = vec3(0.7, 0.2, 0.6);
uniform float spin = 0.004;
uniform float rough = 0.35; // okyanus pürüzlülüğü (oyun arka planında yüksek: ortada parlama olmasın)
varying vec3 lp;

void vertex() { lp = VERTEX; }

void fragment() {
	vec3 n = normalize(lp);
	vec2 uv = vec2(atan(n.z, n.x) / 6.2831853 + 0.5 + TIME * spin, acos(n.y) / 3.14159265);
	float h = texture(land, uv * vec2(2.0, 1.0)).r;
	float isl = smoothstep(0.53, 0.56, h);
	vec3 c = mix(vec3(0.008, 0.03, 0.09), vec3(0.015, 0.07, 0.17), smoothstep(0.3, 0.53, h));
	c = mix(c, mix(vec3(0.06, 0.13, 0.04), vec3(0.3, 0.24, 0.14), smoothstep(0.62, 0.78, h)), isl);
	c = mix(c, vec3(0.9), smoothstep(0.82, 0.95, abs(n.y))); // kutuplar
	float cl = smoothstep(0.56, 0.82, texture(clouds, uv * vec2(4.0, 2.0) + vec2(TIME * spin * 0.6, 0.0)).r);
	c = mix(c, vec3(0.82), cl * 0.75);
	vec3 wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float day = smoothstep(-0.15, 0.25, dot(wn, normalize(sun_dir)));
	ALBEDO = c * (0.08 + 0.75 * day);
	EMISSION = vec3(1.0, 0.75, 0.4) * isl * (1.0 - cl) * (1.0 - day) * smoothstep(0.62, 0.7, texture(clouds, uv * 9.0).r) * 2.0; // şehir ışıkları
	ROUGHNESS = mix(rough, 0.9, isl);
}
