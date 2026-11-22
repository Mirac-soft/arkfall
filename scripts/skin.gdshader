shader_type canvas_item;
// Oyuncu uçağı: renkli dış çizgi (okunurluk) + kozmetik boya ve arma (skin.gd çizer).
// Boya, uçağın kendi parlaklığından çıkarılan gölge ve parlamayla çarpılır: yapıştırma değil, boyanmış gibi durur.
// Kanopi (doygun koyu mavi cam) boyanmaz. Görsel 7 yatış karelik şerit olabilir: desen kare içi koordinatla örneklenir.
uniform vec4 line_col : source_color = vec4(1.0);
uniform float width = 2.2;
uniform float frames = 7.0;
uniform float cx = 0.5;
uniform sampler2D pat : filter_linear;
uniform float has_pat = 0.0;
uniform sampler2D dec : filter_linear;
uniform float has_dec = 0.0;
uniform float gloss = 0.55;
uniform float shine = 0.0;       // parlak boya: kayan parlama + pırıltı
uniform float star_glow = 0.0;   // efsane: desen çizgileri nabız atar
uniform vec4 base_col : source_color = vec4(0.0);
uniform vec4 glow_col : source_color = vec4(0.0);

float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 lu = vec2(fract(UV.x * frames), UV.y);
	vec3 col = c.rgb;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float mx = max(c.r, max(c.g, c.b));
	float sat = mx > 0.0 ? (mx - min(c.r, min(c.g, c.b))) / mx : 0.0;
	bool canopy = c.b >= mx - 0.001 && sat > 0.45 && lum < 0.6 && abs(lu.x - cx) < 18.0 / 256.0;
	float shade = min(1.0, lum * 1.75);
	float hi = clamp((lum - 0.6) * 2.6, 0.0, 1.0);
	if (!canopy) {
		if (has_pat > 0.5) {
			vec3 p = texture(pat, lu).rgb;
			col = p * shade;
			col = 1.0 - (1.0 - col) * (1.0 - vec3(hi * gloss));
			if (star_glow > 0.0) col += p * step(0.18, length(p - base_col.rgb)) * star_glow * (0.6 + 0.4 * sin(TIME * 2.2));
			if (shine > 0.0) {
				float band = fract(TIME * 0.2) * 1.7 - 0.35;
				col += vec3(smoothstep(0.12, 0.0, abs((lu.x + lu.y) * 0.5 - band)) * 0.8 * shine);
				float g = step(0.982, h21(floor(lu * 96.0))) * max(0.0, sin(TIME * 4.0 + h21(floor(lu * 96.0) + 3.0) * 20.0));
				col += vec3(g * 1.4 * shine);
			}
		}
		if (has_dec > 0.5) {
			vec4 d = texture(dec, lu);
			vec3 dc = d.rgb * shade;
			dc = 1.0 - (1.0 - dc) * (1.0 - vec3(hi * 0.45));
			col = mix(col, dc, d.a);
		}
	}
	vec4 body = vec4(col, c.a) * COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	vec3 lc = glow_col.a > 0.0 ? glow_col.rgb * (2.2 + 0.8 * sin(TIME * 3.0)) : line_col.rgb * 2.2;
	vec4 edge = vec4(lc, a * (1.0 - c.a));
	COLOR = vec4(mix(edge.rgb, body.rgb, c.a), max(body.a, edge.a));
}
