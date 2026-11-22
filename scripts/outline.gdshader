shader_type canvas_item;
// Düşmanlara asit yeşili dış çizgi: her zeminde seçilsinler ve pembe düşman mermileriyle karışmasınlar
uniform vec4 line_col : source_color = vec4(0.45, 1.0, 0.1, 1.0);
uniform float width = 1.6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	vec4 edge = vec4(line_col.rgb * 2.2, a * (1.0 - c.a));
	vec4 body = c * COLOR;
	COLOR = vec4(mix(edge.rgb, body.rgb, c.a), max(body.a, edge.a));
}
