shader_type canvas_item;
// Sinematik son işleme: bölge renk tonu (gölge/ışık ayrı), doygunluk, kontrast, vinyet,
// vuruşta renk kayması (chromatic aberration) ve hafif film greni. HUD bunun üstünde kalır.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shadow_col = vec3(1.0);
uniform vec3 high_col = vec3(1.0);
uniform float sat = 1.1;
uniform float contrast = 1.08;
uniform float ca = 0.0;
uniform float vign = 0.55;
uniform float exposure = 0.7; // savaş atmosferi: genel ışık kısık
uniform float knee = 0.62;    // bunun üstündeki parlaklık yumuşakça sıkıştırılır (patlamalar ekranı beyaza boğmasın)
uniform float grain = 0.025;
uniform float hurt = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float off = (ca + hurt * 0.6) * 0.012;
	vec3 c = vec3(texture(screen_tex, uv + d * off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - d * off).b);
	c *= exposure;
	vec3 over = max(c - knee, 0.0);
	c = c - over + over / (1.0 + over * 2.0);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_col, high_col, smoothstep(0.05, 0.9, l));
	float v = dot(d, d);
	c *= 1.0 - v * vign * 2.0;
	c = mix(c, vec3(0.6, 0.0, 0.05), hurt * smoothstep(0.08, 0.35, v) * 0.7); // hasarda kırmızı kenar
	c += (fract(sin(dot(uv * (1.0 + fract(TIME)), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
