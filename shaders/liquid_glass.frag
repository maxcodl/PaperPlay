#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

// A glass lens over whatever is behind it. Used as an ImageFilter, so the engine sets the
// first uniform to the backdrop's size and binds the backdrop to the first sampler.
// All distances are in pixels.
uniform vec2 uSize;
uniform float uRadius;      // corner radius of the shape
uniform float uHeight;      // how far in from the edge the lens bends the backdrop
uniform float uAmount;      // the most it moves a pixel
uniform float uSaturation;
uniform vec4 uTint;         // colour, and how much of it
uniform float uDepth;       // 1 magnifies slightly toward the centre
uniform float uFringe;      // 1 splits red and blue apart at the edge
uniform float uEdgeWidth;
uniform float uEdgeAlpha;
uniform float uEdgeStyle;   // 0 directional, 1 ambient, 2 plain
uniform float uInnerSize;
uniform float uInnerAlpha;
uniform float uDebug;       // 1 paints where each pixel thinks it is
uniform float uDirection;   // 1 shows what's outside the edge at the rim, -1 what's inside
uniform float uProfile;     // 0 circular bend, 1 smooth bend
uniform sampler2D uTexture;

out vec4 fragColor;

// Distance to a rounded box centred on the origin: negative inside.
float boxDistance(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 grab(vec2 pos) {
  return texture(uTexture, clamp(pos, vec2(0.5), uSize - vec2(0.5)) / uSize).rgb;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = frag - halfSize;
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  float inset = max(-boxDistance(p, halfSize, r), 0.0);

  // Which way is out, from the slope of the distance.
  vec2 step = vec2(1.0, 0.0);
  vec2 n = vec2(
      boxDistance(p + step.xy, halfSize, r) - boxDistance(p - step.xy, halfSize, r),
      boxDistance(p + step.yx, halfSize, r) - boxDistance(p - step.yx, halfSize, r));
  n = length(n) > 0.0001 ? normalize(n) : vec2(0.0, -1.0);

  // The lens: 1 at the edge, fading to 0 where it ends, uHeight in. The circular profile
  // bends hardest right at the rim, like the side of a glass dome.
  float t = clamp(1.0 - inset / max(uHeight, 1.0), 0.0, 1.0);
  float bend = uProfile < 0.5 ? 1.0 - sqrt(max(1.0 - t * t, 0.0)) : t * t * (3.0 - 2.0 * t);

  // Depth tilts the push away from the centre as well, so it reaches further in.
  vec2 outward = normalize(p + vec2(0.0001));
  vec2 dir = normalize(n + uDepth * outward) * uDirection;
  vec2 pos = frag + dir * uAmount * bend;

  vec3 color;
  if (uFringe > 0.5) {
    vec2 spread = dir * uAmount * bend * 0.12;
    color = vec3(grab(pos + spread).r, grab(pos).g, grab(pos - spread).b);
  } else {
    color = grab(pos);
  }

  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, uSaturation);
  color = mix(color, uTint.rgb, uTint.a);
  // A soft sheen, lighter toward the top, so the glass reads as lit from above and not flat.
  color += vec3(0.07 * (1.0 - frag.y / uSize.y));

  // A bright rim along the edge. Directional is brightest facing the light, top left.
  float rim = uEdgeWidth > 0.0 ? 1.0 - smoothstep(0.0, uEdgeWidth, inset) : 0.0;
  float facing = dot(n, normalize(vec2(-0.5, -0.85)));
  float strength = uEdgeStyle < 0.5
      ? 0.25 + 0.75 * max(facing, 0.0) + 0.2 * max(-facing, 0.0)
      : (uEdgeStyle < 1.5 ? 0.5 : 0.9);
  color = mix(color, vec3(1.0), clamp(rim * uEdgeAlpha * strength, 0.0, 1.0));

  float glow = uInnerSize > 0.0 ? 1.0 - smoothstep(0.0, uInnerSize, inset) : 0.0;
  color += vec3(glow * uInnerAlpha);

  if (uDebug > 0.5) {
    color = mix(color, vec3(frag.x / uSize.x, frag.y / uSize.y, 0.2), 0.55);
    if (mod(frag.x, 100.0) < 2.0 || mod(frag.y, 100.0) < 2.0) {
      color = vec3(1.0);
    }
  }

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
