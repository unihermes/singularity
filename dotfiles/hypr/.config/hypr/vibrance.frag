// Singularity - Hyprland
// ~/.config/hypr/vibrance.frag
//
// Digital vibrance, as a screen shader: Settings > Display's Vibrance
// slider. displays.lua copies this file into the runtime directory with
// VIBRANCE filled in and sets it as decoration:screen_shader; at the
// slider's middle (0 here) no shader is set at all.
//
// Above 0 it is NVIDIA's kind of vibrance rather than plain saturation:
// dull colours are pushed the most and ones already saturated hardly at
// all, so greys stay grey and bright colours don't clip into flat blocks.
// Below 0 it fades evenly towards greyscale, which -1 reaches.

#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float VIBRANCE = 0.0; // -1..1, written by displays.lua

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 c = pix.rgb;
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    float amount = VIBRANCE > 0.0 ? 1.0 + VIBRANCE * (1.0 - sat) : 1.0 + VIBRANCE;
    fragColor = vec4(clamp(mix(vec3(luma), c, amount), 0.0, 1.0), pix.a);
}
