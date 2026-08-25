#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Every creature is built from the same parts in the same places: a rounded
// body, a beak, two eyes, two feet, and an optional crest. Variety comes from
// their proportions and colours, never from leaving a part out, because a face
// missing a feature reads as wrong rather than as different.
//
// Uniform order is the index contract with CreaturePainter in
// lib/features/creatures/creature_view.dart. Adding one anywhere but the end
// silently shifts every uniform after it.
uniform vec2 uSize;
uniform float uDpr;

uniform vec3 uBody;
uniform vec3 uBelly;
uniform vec3 uTint;

uniform float uSquash;      // above 1 wide and squat, below 1 tall

uniform float uEyeSpacing;
uniform float uEyeSize;

uniform float uCrestLength;  // 0 for a creature with no crest
uniform float uCrestSpread;
uniform float uCrestRadius;

uniform float uBeakSize;
uniform vec3 uBeakColor;

uniform float uFootSize;

uniform float uMarkKind;     // 0 none, 1 spots, 2 stripes, 3 eye mask
uniform float uMarkScale;
uniform float uMarkStrength;
uniform vec3 uMarkColor;

uniform float uGlow;         // rim light for the rare ones

out vec4 fragColor;

const float CAMERA_DISTANCE = 4.6;
const float FOCAL = 1.8;
const float BODY_RADIUS = 0.78;
const int MAX_STEPS = 110;
const float HIT_EPS = 0.0008;
const float MAX_DIST = 9.0;
const float STEP_SCALE = 0.8;

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

vec3 bodyRadii() {
  return vec3(
    BODY_RADIUS * uSquash,
    BODY_RADIUS / uSquash,
    BODY_RADIUS * uSquash);
}

vec3 beakCentre() {
  return vec3(0.0, -0.10, bodyRadii().z * 0.88);
}

// A short beak, wide where it meets the face and narrow at the tip.
float sdBeak(vec3 p) {
  vec3 at = p - beakCentre();
  float taper = 1.0 + 1.4 * max(at.z, 0.0);
  vec3 q = vec3(at.x * taper, at.y * taper, at.z);
  return sdEllipsoid(q, vec3(uBeakSize, uBeakSize * 0.72, uBeakSize * 1.5));
}

// Two feet under the body. Without them the creature floats.
float sdFeet(vec3 p) {
  vec3 mirrored = vec3(abs(p.x), p.y, p.z);
  vec3 at = mirrored - vec3(uFootSize * 1.5, -bodyRadii().y * 0.92, 0.16);
  return sdEllipsoid(at, vec3(uFootSize, uFootSize * 0.55, uFootSize * 1.35));
}

float sdCreature(vec3 p) {
  float d = sdEllipsoid(p, bodyRadii());

  if (uCrestLength > 0.0) {
    // On top of the head and swept back, so it reads as a tuft of down rather
    // than as a pair of horns.
    vec3 mirrored = vec3(abs(p.x), p.y, p.z);
    vec3 base = vec3(uCrestSpread, bodyRadii().y * 0.72, 0.0);
    vec3 tip =
      base + vec3(uCrestLength * 0.30, uCrestLength, -uCrestLength * 0.45);
    d = smoothUnion(d, sdCapsule(mirrored, base, tip, uCrestRadius), 0.09);
  }

  d = smoothUnion(d, sdBeak(p), 0.05);
  d = smoothUnion(d, sdFeet(p), 0.06);
  return d;
}

vec3 normalAt(vec3 p) {
  vec2 e = vec2(0.0035, 0.0);
  return normalize(vec3(
    sdCreature(p + e.xyy) - sdCreature(p - e.xyy),
    sdCreature(p + e.yxy) - sdCreature(p - e.yxy),
    sdCreature(p + e.yyx) - sdCreature(p - e.yyx)));
}

vec3 eyeDirection(float side) {
  return normalize(vec3(side * uEyeSpacing, 0.20, 1.0));
}

float toNearestEye(vec3 n) {
  return min(distance(n, eyeDirection(-1.0)), distance(n, eyeDirection(1.0)));
}

// Coat markings: a short vocabulary, so every creature reads as one family.
float markingMask(vec3 p, vec3 n) {
  if (uMarkKind < 0.5 || uMarkStrength <= 0.0) {
    return 0.0;
  }
  if (uMarkKind < 1.5) {
    return smoothstep(0.58, 0.72, valueNoise(p * uMarkScale));
  }
  if (uMarkKind < 2.5) {
    return smoothstep(0.15, 0.55, abs(sin(p.y * uMarkScale * 2.0)));
  }
  return 1.0 - smoothstep(uEyeSize * 1.7, uEyeSize * 3.1, toNearestEye(n));
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
  skin = mix(skin, uMarkColor, markingMask(p, n) * uMarkStrength);

  vec3 lightDir = normalize(vec3(-0.35, 0.72, 0.6));
  float diffuse = max(dot(n, lightDir), 0.0);
  float ambient = 0.44 + 0.16 * max(n.y, 0.0);
  float fill = max(dot(n, -rd), 0.0) * 0.26;

  vec3 halfVector = normalize(lightDir - rd);
  float specular = pow(max(dot(n, halfVector), 0.0), 40.0) * 0.18;
  float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);

  vec3 color = skin * (ambient + 0.78 * diffuse + fill)
             + uTint * specular
             + uTint * fresnel * (0.20 + uGlow);

  // Beak and feet take their own colour, or they read as lumps of the animal.
  float onBeak = 1.0 - smoothstep(0.0, 0.03, sdBeak(p));
  float onFeet = 1.0 - smoothstep(0.0, 0.03, sdFeet(p));
  color = mix(color, uBeakColor * (0.46 + 0.72 * diffuse), max(onBeak, onFeet));

  // Eyes last, so nothing draws over them.
  float eye = 1.0 - smoothstep(uEyeSize * 0.78, uEyeSize, toNearestEye(n));

  // Two highlights. One dot on a dark oval reads as a socket; a pair reads as
  // an eye looking back.
  float glint = 1.0 - smoothstep(
    uEyeSize * 0.22,
    uEyeSize * 0.38,
    distance(n, normalize(vec3(-uEyeSpacing + 0.09, 0.32, 1.0))));
  float underGlint = 1.0 - smoothstep(
    uEyeSize * 0.10,
    uEyeSize * 0.20,
    distance(n, normalize(vec3(uEyeSpacing + 0.03, 0.06, 1.0))));

  color = mix(color, vec3(0.12, 0.10, 0.15), eye);
  color = mix(color, vec3(1.0), eye * glint * 0.95);
  color = mix(color, vec3(1.0), eye * underGlint * 0.5);

  fragColor = vec4(color * alpha, alpha); // premultiplied
}
