shader_type canvas_item;
// Yatış ışıklandırması: yatan kanat kararır, kalkan kanat parlar (uçağın yerel x ekseni)
uniform float bank = 0.0;
void fragment() {
	COLOR.rgb *= 1.0 + bank * (UV.x - 0.5) * 1.3;
}
