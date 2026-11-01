shader_type canvas_item;
// 選機畫面的戰機卡片：側邊時模糊＋變暗；glow 模式用來畫背後的光暈（加亮混合請用 ship_glow）。

uniform float blur = 0.0;      // 模糊半徑（UV 比例）
uniform float dim = 0.0;       // 0 = 原色，1 = 全黑

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (blur > 0.0005) {
		vec4 acc = c;
		float n = 1.0;
		for (int i = 1; i <= 4; i++) {
			float o = blur * float(i) / 4.0;
			// 水平方向為主（動態模糊感），加一點垂直
			acc += texture(TEXTURE, UV + vec2(o, 0.0));
			acc += texture(TEXTURE, UV - vec2(o, 0.0));
			acc += texture(TEXTURE, UV + vec2(0.0, o * 0.35));
			acc += texture(TEXTURE, UV - vec2(0.0, o * 0.35));
			n += 4.0;
		}
		c = acc / n;
	}
	c.rgb *= (1.0 - dim);
	COLOR = c * COLOR;
}
