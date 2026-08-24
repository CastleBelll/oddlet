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
uniform float uEyeSpacing; // how far apart the eyes sit
uniform float uEyeSize;

out vec4 fragColor;

const float CAMERA_DISTANCE = 4.2;
const float FOCAL = 1.8;
const float BODY_RADIUS = 0.86;
const int MAX_STEPS = 96;
const float HIT_EPS = 0.0008;
const float MAX_DIST = 8.0;
const float STEP_SCALE = 0.85;

// Placeholder anatomy: a blob with two eyes. Enough to read as alive, and
// cheap enough to throw away when the real art direction lands.
float sdBody(vec3 p) {
  vec3 radii = vec3(
    BODY_RADIUS * uSquash,
    BODY_RADIUS / uSquash,
    BODY_RADIUS * uSquash);

  float k1 = length(p / radii);
  float k2 = max(length(p / (radii * radii)), 1e-6);
  return k1 * (k1 - 1.0) / k2;
}

vec3 normalAt(vec3 p) {
  vec2 e = vec2(0.0015, 0.0);
  return normalize(vec3(
    sdBody(p + e.xyy) - sdBody(p - e.xyy),
    sdBody(p + e.yxy) - sdBody(p - e.yxy),
    sdBody(p + e.yyx) - sdBody(p - e.yyx)));
}

// Eyes are placed by surface direction rather than carved into the shape,
// which keeps the silhouette clean.
vec3 eyeDirection(float side) {
  return normalize(vec3(side * uEyeSpacing, 0.16, 1.0));
}

// How much of this point is eye.
float eyeMask(vec3 n) {
  float nearest = min(
    distance(n, eyeDirection(-1.0)),
    distance(n, eyeDirection(1.0)));
  return 1.0 - smoothstep(uEyeSize * 0.75, uEyeSize, nearest);
}

// Both eyes catch the same light. One lit eye and one dead one reads as a
// rendering fault rather than a face.
float eyeGlint(vec3 n) {
  vec3 offset = vec3(0.06, 0.08, 0.0);
  float nearest = min(
    distance(n, normalize(eyeDirection(-1.0) + offset)),
    distance(n, normalize(eyeDirection(1.0) + offset)));
  return 1.0 - smoothstep(uEyeSize * 0.20, uEyeSize * 0.34, nearest);
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
    float d = sdBody(p);
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
             + uTint * fresnel * 0.22;

  float eye = eyeMask(n);
  vec3 eyeColor = vec3(0.06, 0.05, 0.08);
  // A highlight is most of what makes an eye look awake.
  float glint = eyeGlint(n);

  color = mix(color, eyeColor, eye);
  color = mix(color, vec3(1.0), eye * glint * 0.9);

  fragColor = vec4(color * alpha, alpha); // premultiplied
}
