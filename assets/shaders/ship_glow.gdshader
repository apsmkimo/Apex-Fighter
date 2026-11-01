shader_type canvas_item;
render_mode blend_add;
// 戰機背後的光暈：取貼圖輪廓做大範圍模糊，染成指定顏色後加亮疊上去。
// 這個節點要比戰機大 pad 倍，光暈才有空間往外擴散。

uniform vec4 glow_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float radius = 0.04;
uniform float strength = 1.0;
uniform float pad = 1.4;

void fragment() {
	vec2 uv = (UV - 0.5) * pad + 0.5;
	float a = 0.0;
	float n = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 p = uv + vec2(float(x), float(y)) * radius / 3.0;
			float inside = step(0.0, p.x) * step(0.0, p.y) * step(p.x, 1.0) * step(p.y, 1.0);
			a += texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0))).a * inside;
			n += 1.0;
		}
	}
	a /= n;
	COLOR = vec4(glow_color.rgb * a * strength * COLOR.a, 1.0);
}
