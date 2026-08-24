#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Uniform order is a contract with EggPainter in lib/features/egg/egg_view.dart.
uniform vec2 uSize;   // paint box size, logical pixels
uniform float uDpr;   // device pixel ratio, for edge antialiasing width
uniform float uYaw;   // camera orbit, radians
uniform float uPitch; // camera elevation, radians
uniform vec3 uShell;   // shell color
uniform vec3 uSpeckle; // pattern color across the shell
uniform vec3 uTint;    // rim / specular tint

uniform float uTextureScale;    // larger is finer
uniform float uTextureContrast; // how strongly the pattern shows
uniform float uBlotchiness;     // 0 even freckles, 1 broad blotches
uniform float uNoiseOffset;     // shifts the pattern between eggs

out vec4 fragColor;

const float CAMERA_DISTANCE = 4.2;
const float FOCAL = 1.8;
const float EGG_RADIUS_XZ = 0.86; // chubby rather than slender
const float EGG_TAPER = 0.20;     // how much narrower the top half is
const int MAX_STEPS = 96;
const float HIT_EPS = 0.0008;
const float MAX_DIST = 8.0;
// The taper makes sdEgg a loose distance bound, so march conservatively.
const float STEP_SCALE = 0.7;

mat3 rotX(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c);
}

mat3 rotY(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c);
}

// Signed distance to an ellipsoid that narrows toward +y, i.e. an egg.
float sdEgg(vec3 p) {
  // Smooth across the whole height; a kink here would show as a seam in the
  // normals at the equator.
  float taper = 1.0 + EGG_TAPER * (0.5 * p.y + 0.5);
  vec3 q = vec3(p.x * taper, p.y, p.z * taper);
  vec3 radii = vec3(EGG_RADIUS_XZ, 1.0, EGG_RADIUS_XZ);
  // Tight ellipsoid bound. The naive (length(q/r) - 1) * min(r) form
  // underestimates so badly that rays run out of march steps and band.
  float k1 = length(q / radii);
  float k2 = max(length(q / (radii * radii)), 1e-6);
  return k1 * (k1 - 1.0) / k2;
}

vec3 normalAt(vec3 p) {
  vec2 e = vec2(0.0015, 0.0);
  return normalize(vec3(
    sdEgg(p + e.xyy) - sdEgg(p - e.xyy),
    sdEgg(p + e.yxy) - sdEgg(p - e.yxy),
    sdEgg(p + e.yyx) - sdEgg(p - e.yyx)));
}

// Sin-free: sin() of large arguments loses precision on mobile GPUs and the
// error shows up as concentric rings across the shell.
float hash(vec3 p) {
  vec3 q = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
  q *= 17.0;
  return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

float valueNoise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  // Quintic rather than cubic: cubic leaves the lattice visible as blocks once
  // the pattern gets fine.
  f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  return mix(
    mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
        mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
    mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
        mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
    f.z);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag - 0.5 * uSize) / uSize.y;
  uv.y = -uv.y;

  mat3 camera = rotY(uYaw) * rotX(uPitch);
  vec3 ro = camera * vec3(0.0, 0.0, CAMERA_DISTANCE);
  vec3 rd = camera * normalize(vec3(uv, -FOCAL));

  // March, tracking the closest approach so the silhouette can be antialiased.
  float t = 0.0;
  float tHit = -1.0;
  float dMin = MAX_DIST;
  float tMin = 0.0;

  for (int i = 0; i < MAX_STEPS; i++) {
    vec3 p = ro + rd * t;
    float d = sdEgg(p);
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

  // A hit is fully opaque. Only rays that missed fade out, which antialiases
  // the silhouette; using dMin for hits too would modulate the opacity of the
  // whole shell and show up as rings.
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

  // Shell pattern, also what makes rotation read as rotation on a shape this
  // symmetric. Two octaves: fine freckles blended toward broad blotches.
  // Two octaves per band, so no single lattice dominates the surface.
  vec3 patternPoint = p + vec3(uNoiseOffset);
  float freckles = 0.62 * valueNoise(patternPoint * uTextureScale) +
                   0.38 * valueNoise(patternPoint * uTextureScale * 2.13 + 7.0);
  float blotches =
      0.62 * valueNoise(patternPoint * uTextureScale * 0.35) +
      0.38 * valueNoise(patternPoint * uTextureScale * 0.74 + 3.0);
  float pattern = mix(freckles, blotches, uBlotchiness);

  vec3 shell = mix(
    uShell,
    uSpeckle,
    clamp(pattern * uTextureContrast * 3.0, 0.0, 1.0));

  vec3 lightDir = normalize(vec3(-0.45, 0.75, 0.55));
  float diffuse = max(dot(n, lightDir), 0.0);
  float ambient = 0.34 + 0.18 * max(n.y, 0.0);

  // Fill light fixed to the camera, so orbiting to the unlit side still leaves
  // the shell readable instead of going black.
  float fill = max(dot(n, -rd), 0.0) * 0.32;

  vec3 halfVector = normalize(lightDir - rd);
  float specular = pow(max(dot(n, halfVector), 0.0), 42.0) * 0.16;

  float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);

  vec3 color = shell * (ambient + 0.85 * diffuse + fill)
             + uTint * specular
             + uTint * fresnel * 0.20;

  fragColor = vec4(color * alpha, alpha); // premultiplied
}
