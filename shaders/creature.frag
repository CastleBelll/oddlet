#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Uniform order is a contract with CreaturePainter in
// lib/features/creatures/creature_view.dart.
uniform vec2 uSize;
uniform float uDpr;

uniform vec3 uBody;
uniform vec3 uBelly;
uniform vec3 uTint;

uniform float uSquash;     // above 1 wide and squat, below 1 tall
uniform float uEyeSpacing;
uniform float uEyeSize;
uniform float uEyeCount;   // 1, 2 or 3

uniform float uEarLength;  // 0 for no ears
uniform float uEarSpread;
uniform float uEarRadius;

uniform float uLumpHeight; // a second mass fused to the body
uniform float uLumpRadius; // 0 for a single mass

uniform float uBumpiness;  // 0 smooth, 1 lumpy hide
uniform float uGlow;       // rim light for the rare ones

out vec4 fragColor;

const float CAMERA_DISTANCE = 4.4;
const float FOCAL = 1.8;
const float BODY_RADIUS = 0.80;
const int MAX_STEPS = 128;
const float HIT_EPS = 0.0008;
const float MAX_DIST = 9.0;
// Surface displacement breaks the distance bound, so march short steps.
const float STEP_SCALE = 0.55;

// Smooth union: parts fuse into one animal rather than reading as glued
// together.
float smoothUnion(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float sdEllipsoid(vec3 p, vec3 radii) {
  float k1 = length(p / radii);
  float k2 = max(length(p / (radii * radii)), 1e-6);
  return k1 * (k1 - 1.0) / k2;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float radius) {
  vec3 pa = p - a;
  vec3 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - radius;
}

float hash(vec3 p) {
  vec3 q = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
  q *= 17.0;
  return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

float valueNoise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  return mix(
    mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
        mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
    mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
        mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
    f.z);
}

// The animal without its surface texture. Eyes are placed against this so a
// lumpy hide cannot scatter them across the body.
float sdBody(vec3 p) {
  vec3 radii = vec3(
    BODY_RADIUS * uSquash,
    BODY_RADIUS / uSquash,
    BODY_RADIUS * uSquash);
  float d = sdEllipsoid(p, radii);

  if (uLumpRadius > 0.0) {
    float lump = sdEllipsoid(
      p - vec3(0.0, uLumpHeight, 0.0),
      vec3(uLumpRadius));
    d = smoothUnion(d, lump, 0.28);
  }

  if (uEarLength > 0.0) {
    // Mirrored across x, so the pair matches without drawing it twice.
    vec3 mirrored = vec3(abs(p.x), p.y, p.z);
    vec3 base = vec3(uEarSpread, 0.30, 0.0);
    vec3 tip = vec3(
      uEarSpread + uEarLength * 0.45,
      0.30 + uEarLength,
      -0.05);
    d = smoothUnion(d, sdCapsule(mirrored, base, tip, uEarRadius), 0.10);
  }

  return d;
}

float sdCreature(vec3 p) {
  float d = sdBody(p);
  if (uBumpiness > 0.0) {
    // Coarse and shallow: at a fine scale this reads as rendering noise
    // rather than as a hide.
    d -= uBumpiness * (valueNoise(p * 3.2) - 0.5) * 0.09;
  }
  return d;
}

/// Wide sample, so the lumps shade as lumps instead of speckling.
vec3 normalAt(vec3 p) {
  vec2 e = vec2(0.007, 0.0);
  return normalize(vec3(
    sdCreature(p + e.xyy) - sdCreature(p - e.xyy),
    sdCreature(p + e.yxy) - sdCreature(p - e.yxy),
    sdCreature(p + e.yyx) - sdCreature(p - e.yyx)));
}

vec3 smoothNormalAt(vec3 p) {
  vec2 e = vec2(0.004, 0.0);
  return normalize(vec3(
    sdBody(p + e.xyy) - sdBody(p - e.xyy),
    sdBody(p + e.yxy) - sdBody(p - e.yxy),
    sdBody(p + e.yyx) - sdBody(p - e.yyx)));
}

vec3 eyeDirection(float side) {
  return normalize(vec3(side * uEyeSpacing, 0.16, 1.0));
}

// Distance from this point to whichever eye is closest.
float toNearestEye(vec3 n) {
  float nearest = uEyeCount < 1.5
    ? distance(n, normalize(vec3(0.0, 0.12, 1.0)))
    : min(distance(n, eyeDirection(-1.0)), distance(n, eyeDirection(1.0)));

  if (uEyeCount > 2.5) {
    nearest = min(nearest, distance(n, normalize(vec3(0.0, 0.62, 1.0))));
  }
  return nearest;
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - 0.5 * uSize) / uSize.y;
  uv.y = -uv.y;

  vec3 ro = vec3(0.0, 0.0, CAMERA_DISTANCE);
  vec3 rd = normalize(vec3(uv, -FOCAL));

  float t = 0.0;
  float tHit = -1.0;
  float dMin = MAX_DIST;
  float tMin = 0.0;

  for (int i = 0; i < MAX_STEPS; i++) {
    vec3 p = ro + rd * t;
    float d = sdCreature(p);
    if (d < dMin) {
      dMin = d;
      tMin = t;
    }
    if (d < HIT_EPS) {
      tHit = t;
      break;
    }
    t += d * STEP_SCALE;
    if (t > MAX_DIST) {
      break;
    }
  }

  float alpha = 1.0;
  if (tHit < 0.0) {
    float edge = 2.0 / (uDpr * uSize.y);
    alpha = 1.0 - smoothstep(0.0, edge, dMin);
    if (alpha <= 0.0) {
      fragColor = vec4(0.0);
      return;
    }
  }

  vec3 p = ro + rd * (tHit > 0.0 ? tHit : tMin);
  vec3 n = normalAt(p);

  // Pale underside, the way most small animals are counter-shaded.
  vec3 skin = mix(uBody, uBelly, smoothstep(0.1, -0.8, n.y));

  vec3 lightDir = normalize(vec3(-0.4, 0.7, 0.6));
  float diffuse = max(dot(n, lightDir), 0.0);
  float ambient = 0.40 + 0.16 * max(n.y, 0.0);
  float fill = max(dot(n, -rd), 0.0) * 0.28;

  vec3 halfVector = normalize(lightDir - rd);
  float specular = pow(max(dot(n, halfVector), 0.0), 38.0) * 0.20;
  float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);

  vec3 color = skin * (ambient + 0.8 * diffuse + fill)
             + uTint * specular
             + uTint * fresnel * (0.22 + uGlow);

  float nearestEye = toNearestEye(smoothNormalAt(p));
  float eye = 1.0 - smoothstep(uEyeSize * 0.75, uEyeSize, nearestEye);
  // A highlight is most of what makes an eye look awake.
  float glint = 1.0 - smoothstep(
    uEyeSize * 0.18,
    uEyeSize * 0.30,
    distance(n, normalize(vec3(-uEyeSpacing + 0.07, 0.26, 1.0))));

  color = mix(color, vec3(0.06, 0.05, 0.08), eye);
  color = mix(color, vec3(1.0), eye * glint * 0.85);

  fragColor = vec4(color * alpha, alpha); // premultiplied
}
