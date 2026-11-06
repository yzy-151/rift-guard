shader_type canvas_item;
render_mode blend_mix;

uniform float saturation : hint_range(0.0, 2.0) = 1.10;
uniform float contrast : hint_range(0.5, 1.5) = 1.08;
uniform float distant_haze : hint_range(0.0, 0.5) = 0.025;
uniform vec3 ambient_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 haze_color = vec3(0.62, 0.69, 0.74);

void fragment() {
    vec4 base = COLOR;
    float luminance = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    base.rgb = mix(vec3(luminance), base.rgb, saturation);
    base.rgb = (base.rgb - vec3(0.5)) * contrast + vec3(0.5);
    float depth = clamp((FRAGCOORD.y - 120.0) / 560.0, 0.0, 1.0);
    base.rgb = mix(base.rgb, haze_color, (1.0 - depth) * distant_haze * base.a);
    base.rgb *= ambient_tint;
    COLOR = base;
}
