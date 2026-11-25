// SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later
//
// The "Monochrome" icon stylization (IconStylizer.qml). After a change, rebuild the .qsb:
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o monochrome.frag.qsb monochrome.frag
//
// The icon's brightness only, with auto levels: stretched from the icon's own
// darkest and lightest tones [lo, hi] to the whole range, so a pale icon
// doesn't turn into a grey smudge; then a contrast around the middle. The
// result runs from darkColor to lightColor.

#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lo;
    float hi;
    float contrast;
    vec4 darkColor;
    vec4 lightColor;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    if (c.a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float y = dot(c.rgb / c.a, vec3(0.2126, 0.7152, 0.0722));
    y = clamp((y - lo) / max(0.001, hi - lo), 0.0, 1.0);
    y = clamp((y - 0.5) * contrast + 0.5, 0.0, 1.0);
    vec3 col = mix(darkColor.rgb, lightColor.rgb, y);
    fragColor = vec4(col, 1.0) * c.a * qt_Opacity;
}
