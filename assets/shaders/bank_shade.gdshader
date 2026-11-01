shader_type canvas_item;
// 機身傾斜時的假 3D 明暗：往下沉的那一側變暗，抬起的那一側變亮。
// bank：-1 ~ 1，正值 = 向右傾（右翼往下）。

uniform float bank = 0.0;
uniform float shade = 0.45;

void fragment() {
	float x = (UV.x - 0.5) * 2.0;          // 左 -1 ~ 右 1
	float f = 1.0 - bank * x * shade;      // 下沉側 < 1，抬起側 > 1
	COLOR.rgb *= clamp(f, 0.45, 1.5);
	// 抬起側加一點反光
	COLOR.rgb += vec3(0.12, 0.16, 0.2) * max(-bank * x, 0.0) * COLOR.a;
}
