shader_type canvas_item;
uniform sampler2D visiual;
uniform float size:hint_range(0.0, 1.0);

void fragment() {
	vec2 uv = (2.*UV)-1.;
	COLOR.a= step(length(uv),size);
}
