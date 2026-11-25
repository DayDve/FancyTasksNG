// SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later
//
// The "Outline" icon stylization (IconStylizer.qml). After a change, rebuild the .qsb:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o outline.frag.qsb outline.frag
//
// Edge detection (Sobel): a line wherever the icon's color, brightness or
// opacity changes sharply, transparent elsewhere. Denser than "Lines": every
// edge is drawn, on both of its sides.

#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;       // one source pixel, times the line thickness
    float threshold;  // edge strength below which nothing is drawn
    vec4 lineColor;
};
layout(binding = 1) uniform sampler2D source;

const float softness = 0.15;  // ramp above the threshold

vec4 px(vec2 d) { return texture(source, qt_TexCoord0 + d * texel); }

void main() {
    vec4 tl = px(vec2(-1, -1)), t = px(vec2(0, -1)), tr = px(vec2(1, -1));
    vec4 l  = px(vec2(-1,  0)),                      r  = px(vec2(1,  0));
    vec4 bl = px(vec2(-1,  1)), b = px(vec2(0,  1)), br = px(vec2(1,  1));
    vec4 gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    vec4 gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
    // The strongest change of any channel (premultiplied colors and opacity).
    vec4 g = sqrt(gx * gx + gy * gy);
    float m = max(max(g.r, g.g), max(g.b, g.a)) / 4.0;
    float a = smoothstep(threshold, threshold + softness, m);
    fragColor = vec4(lineColor.rgb, 1.0) * lineColor.a * a * qt_Opacity;
}
