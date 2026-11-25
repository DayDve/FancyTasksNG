// SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later
//
// The "Lines" icon stylization (IconStylizer.qml). After a change, rebuild the .qsb:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o lines.frag.qsb lines.frag
//
// A line drawing of the icon: a difference of Gaussians (DoG, as in XDoG,
// Winnemöller 2012). Ink where the icon is darker than its surroundings at
// the scale of `sigma`: a thin dark stroke gives one line, a small dark spot
// stays a filled spot, a large area gets a line along its border, and a
// flat area or a smooth gradient gives nothing. Run on the brightness (over
// white "paper"; inverted for a mostly dark icon, whose drawing is light) and
// on the silhouette (the shape as ink); the stronger of the two wins.

#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;       // one source pixel
    float sigma;      // in source pixels: the line thickness
    float invert;     // 1: a light drawing on a mostly dark icon
    vec4 lineColor;
};
layout(binding = 1) uniform sampler2D source;

const float k = 1.6;     // ratio of the two blurs
const float tau = 0.99;  // below 1: a flat area, dark or light, gets no ink
const float eps = -0.01; // how much darker than around a pixel must be
const float phi = 120.0; // steepness of the ink ramp

float ink(float g1, float g2) {
    float d = g1 - tau * g2;
    float e = d >= eps ? 1.0 : 1.0 + tanh(phi * (d - eps));
    return clamp(1.0 - e, 0.0, 1.0);
}

void main() {
    float s2 = k * sigma;
    int r = int(ceil(2.5 * s2));
    vec2 sum1 = vec2(0.0), sum2 = vec2(0.0);   // x: brightness, y: silhouette
    float w1 = 0.0, w2 = 0.0;
    for (int y = -8; y <= 8; y++) {
        if (abs(y) > r) continue;
        for (int x = -8; x <= 8; x++) {
            if (abs(x) > r) continue;
            vec4 c = texture(source, qt_TexCoord0 + vec2(x, y) * texel);
            float a = c.a;
            float l = a > 0.0 ? dot(c.rgb / a, vec3(0.2126, 0.7152, 0.0722)) : 1.0;
            float v = invert > 0.5 ? 1.0 - a * l : mix(1.0, l, a);
            vec2 val = vec2(v, 1.0 - a);
            float d2 = float(x * x + y * y);
            float a1 = exp(-d2 / (2.0 * sigma * sigma));
            float a2 = exp(-d2 / (2.0 * s2 * s2));
            sum1 += a1 * val; w1 += a1;
            sum2 += a2 * val; w2 += a2;
        }
    }
    sum1 /= w1;
    sum2 /= w2;
    float m = max(ink(sum1.x, sum2.x), ink(sum1.y, sum2.y));
    fragColor = vec4(lineColor.rgb, 1.0) * lineColor.a * m * qt_Opacity;
}
