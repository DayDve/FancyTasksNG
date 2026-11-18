// SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later
//
// The Shatter close effect (ShatterEffect.qml). After a change, rebuild the .qsb:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o shatter.frag.qsb shatter.frag

#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0: whole, 1: gone
    float seed;
    // The icon's place in this quad (x, y, width, height, in 0..1).
    float iconX;
    float iconY;
    float iconW;
    float iconH;
    // Away from the panel edge, where the window has room.
    float awayX;
    float awayY;
};
layout(binding = 1) uniform sampler2D source;

float hash(float n) {
    return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

const int GRID = 4;
const int CELLS = GRID * GRID;

vec2 cellCenter(int i) {
    vec2 g = vec2(float(i % GRID), float(i / GRID));
    return (g + 0.2 + 0.6 * vec2(hash(float(i) * 3.1), hash(float(i) * 5.7 + 1.0))) / float(GRID);
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - vec2(iconX, iconY)) / vec2(iconW, iconH);
    vec2 away = vec2(awayX, awayY);

    // A short swell and flash, then the pieces fly, fast at first.
    float sp = clamp((progress - 0.06) / 0.94, 0.0, 1.0);
    float t = 1.0 - pow(1.0 - sp, 2.5);
    float swell = 1.0 + 0.12 * smoothstep(0.0, 0.06, progress) * (1.0 - sp);

    vec4 outColor = vec4(0.0);
    for (int i = 0; i < CELLS; ++i) {
        vec2 c = cellCenter(i);
        vec2 dir = normalize((c - 0.5) * 2.0 + away * 0.9
                             + (vec2(hash(float(i) * 7.3 + 2.0), hash(float(i) * 9.1 + 3.0)) - 0.5) * 0.8);
        float speed = 0.5 + 0.8 * hash(float(i) * 13.7 + 4.0);
        float spin = (hash(float(i) * 17.3 + 5.0) - 0.5) * 6.0 * t;
        float shrink = 1.0 - 0.35 * t;

        // Where this piece's pixel came from in the icon.
        vec2 local = rot(-spin) * (p - c - dir * speed * t) / shrink;
        vec2 q = c + local;
        if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0)
            continue;
        // Does that pixel belong to this piece?
        float d1 = 1e9, d2 = 1e9;
        int nearest = 0;
        for (int j = 0; j < CELLS; ++j) {
            float d = distance(q, cellCenter(j));
            if (d < d1) {
                d2 = d1;
                d1 = d;
                nearest = j;
            } else if (d < d2) {
                d2 = d;
            }
        }
        if (nearest != i)
            continue;

        vec2 sq = 0.5 + (q - 0.5) / swell;
        vec4 tex = texture(source, sq);
        if (tex.a <= 0.0)
            continue;
        vec3 col = tex.rgb / tex.a;
        // Flash, glowing cracks, then the pieces char as they fly.
        float flash = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.05, 0.22, progress));
        col = mix(col, vec3(1.0, 0.95, 0.8), flash * 0.75);
        float crack = 1.0 - smoothstep(0.0, 0.035, d2 - d1);
        col = mix(col, vec3(1.0, 0.55, 0.1), crack * smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.0, 0.5, t)));
        col *= 1.0 - 0.45 * t;
        float a = tex.a * (1.0 - smoothstep(0.5, 1.0, progress));
        outColor = vec4(col * a, a);
        break;
    }
    // Pieces fade out near the edges of the window's room.
    float border = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    fragColor = outColor * smoothstep(0.0, 0.06, border) * qt_Opacity;
}
