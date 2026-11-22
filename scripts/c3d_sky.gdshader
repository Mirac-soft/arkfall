shader_type sky;
// Ara sahne gökyüzü: üst / ufuk / alt renk, güneş diski + halesi, gece ve uzay için yıldızlar
uniform vec3 top_col : source_color = vec3(0.18, 0.32, 0.6);
uniform vec3 hor_col : source_color = vec3(0.75, 0.82, 0.9);
uniform vec3 bot_col : source_color = vec3(0.3, 0.32, 0.35);
uniform vec3 sun_dir = vec3(0.3, 0.25, -1.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.92, 0.75);
uniform float sun_size = 0.0005;
uniform float sun_glow = 0.16;
uniform float stars = 0.0;
uniform float star_floor = 0.0; // 1: ufkun altında da yıldız (uzayda tepeden bakış)

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 c = h > 0.0 ? mix(hor_col, top_col, pow(clamp(h, 0.0, 1.0), 0.55)) : mix(hor_col, bot_col, pow(clamp(-h, 0.0, 1.0), 0.4));
	vec3 sd = normalize(sun_dir);
	float sa = max(dot(d, sd), 0.0);
	c += sun_col * (smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.5, sa) * 3.0 + pow(sa, 220.0) * sun_glow * 2.0 + pow(sa, 12.0) * sun_glow * 0.3); // küçük disk, yumuşak hale
	if (stars > 0.0) {
		vec3 q = floor(d * 380.0);
		float s = hash(q);
		float tw = 0.6 + 0.4 * sin(TIME * (1.0 + s * 3.0) + s * 40.0);
		c += vec3(smoothstep(1.0 - 0.0035 * stars, 1.0, s) * 2.2 * tw) * max(smoothstep(-0.2, 0.1, h + 0.3), star_floor);
	}
	COLOR = c;
}
