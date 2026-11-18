// SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later
//
// The Force Quit burn (BurnEffect.qml). After a change, rebuild the .qsb:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o burn.frag.qsb burn.frag

#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0: whole, 1: gone
    float time;       // seconds, for the flicker
    float seed;
    // Where the burn starts and where it goes: t = axisX * u + axisY * v
    // + axisC runs from 0 at the panel edge to 1 at the far side.
    float axisX;
    float axisY;
    float axisC;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < 4; ++k) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);
    // Where the fire front reaches this pixel: from the panel edge on,
    // ragged.
    float t = axisX * uv.x + axisY * uv.y + axisC;
    float n = fbm(uv * 5.0 + vec2(seed, seed * 1.7) + vec2(axisX, -axisY) * time * 0.6);
    float h = t * 0.7 + n * 0.45;
    float front = progress * 1.3 - 0.05;
    float d = h - front;   // < 0: burnt away

    if (d < 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float flicker = 0.85 + 0.15 * noise(uv * 30.0 + time * 12.0);
    // Glowing rim: white-yellow at the very edge, then orange, then red.
    vec3 hot = mix(vec3(1.0, 0.95, 0.6), vec3(1.0, 0.45, 0.05), smoothstep(0.0, 0.035, d));
    hot = mix(hot, vec3(0.6, 0.08, 0.0), smoothstep(0.035, 0.07, d));
    float rim = 1.0 - smoothstep(0.0, 0.07, d);
    // Ahead of the rim the icon chars: darker and browner the closer it is.
    float charring = 1.0 - smoothstep(0.05, 0.22, d);
    vec3 col = c.rgb;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(0.12, 0.06, 0.03) * (0.5 + lum), charring * 0.85);
    // The rim glows even over transparent parts of the icon, but only next
    // to something that burns.
    float body = c.a;
    vec3 outRgb = mix(col * body, hot * flicker, rim);
    float outA = max(body, rim * body * 1.0);
    fragColor = vec4(outRgb, outA) * qt_Opacity;
}
