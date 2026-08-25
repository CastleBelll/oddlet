#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Uniform order is a contract with HatchDebris in
// lib/features/egg/hatch_debris.dart.
uniform vec2 uSize;   // paint box size, logical pixels
uniform float uDpr;   // device pixel ratio, for edge antialiasing width
uniform float uUnit;  // the egg's own box height, in the same logical pixels
uniform float uYaw;   // camera orbit, radians
uniform float uPitch; // camera elevation, radians
uniform float uCrack; // 0 whole shell, 1 split open
uniform vec3 uShell;  // what the broken pieces are made of
uniform vec3 uGlow;   // the light they came away from

out vec4 fragColor;

const float CAMERA_DISTANCE = 4.2;
const float FOCAL = 1.8;
const float EGG_RADIUS_XZ = 0.86;

const float PEEL_FIRST = 0.34;

const int SHARD_COUNT = 16;
const float SHARD_SIZE = 0.15;
const float SHARD_SPEED = 2.3;
const float SHARD_FALL = 2.4;
const float SHARD_LIFE = 0.55;

const int DUST_COUNT = 22;
const float DUST_SIZE = 0.032;
const float DUST_SPEED = 3.4;
const float DUST_FALL = 3.6;
const float DUST_LIFE = 0.38;


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


// Sin-free: sin() of large arguments loses precision on mobile GPUs and the
// error shows up as concentric rings across the shell.
float hash(vec3 p) {
  vec3 q = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
  q *= 17.0;
  return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}


vec3 hash3(vec3 p) {
  return vec3(hash(p), hash(p + 19.19), hash(p + 47.71));
}

/// land is enough, and it is the movement that says the shell broke.
vec4 shardLayer(vec2 uv, vec3 ro) {
  vec4 result = vec4(0.0);
  if (uCrack <= 0.0) {
    return result;
  }

  // The camera rotation undone. Built from the angles rather than by
  // transposing the matrix: spirv-cross turns transpose() into a helper that
  // SkSL does not have, so the shader compiles for Impeller and is rejected
  // everywhere else.
  mat3 toCamera = rotX(-uPitch) * rotY(-uYaw);

  // One rendered pixel, in the units uv is measured in. Edges are softened by
  // this rather than by a fixed amount, so they stay a pixel wide whatever
  // the screen is.
  float pixel = 1.0 / (uDpr * uSize.y);

  for (int i = 0; i < SHARD_COUNT; i++) {
    vec3 h = hash3(vec3(float(i) * 1.7, 5.3, 2.9));

    // Where on the shell it broke off, weighted toward the crown, which is
    // where the shell opens.
    float phi = h.x * 6.2831853;
    float up = mix(1.0, -0.2, h.y * h.y);
    float ring = sqrt(max(0.0, 1.0 - up * up));
    vec3 outward = vec3(ring * cos(phi), up, ring * sin(phi));
    vec3 origin = outward * vec3(EGG_RADIUS_XZ, 1.0, EGG_RADIUS_XZ);

    // Higher pieces leave first, in the same order the openings appear.
    float turn = mix(PEEL_FIRST, PEEL_FIRST + 0.50, 0.5 - 0.5 * up)
               + 0.12 * h.z;
    float age = uCrack - turn;
    if (age <= 0.0) {
      continue;
    }

    // Thrown clear, then falling. Both matter: without the throw it drips off
    // the egg, without the fall it floats.
    vec3 pos = origin
             + outward * (age * SHARD_SPEED)
             + vec3(0.0, -SHARD_FALL * age * age, 0.0);

    vec3 view = toCamera * (pos - ro);
    if (view.z > -0.05) {
      continue;
    }

    vec2 at = view.xy * FOCAL / (-view.z);
    // Pieces are not all the same size; a row of identical chips reads as a
    // particle system rather than as one thing that broke.
    float scale = SHARD_SIZE * mix(0.55, 1.35, h.z) * FOCAL / (-view.z);

    // Tumbling, which is most of what sells a falling piece.
    float spin = age * (3.0 + 7.0 * h.x) + h.y * 6.2831853;
    float c = cos(spin);
    float s = sin(spin);
    vec2 local = (mat2(c, -s, s, c) * (uv - at)) / scale;

    // A chip with corners rather than a disc: shell does not break into
    // pebbles.
    float chip = max(abs(local.x) * 0.85 + abs(local.y) * 0.65,
                     max(abs(local.x), abs(local.y)) * 0.9);
    // Softened by a screen pixel rather than by a fixed amount, so a piece is
    // as crisp far away as it is close and does not turn to mush on a small
    // one. The old fixed width blurred a distant chip into a smudge.
    float soft = clamp(pixel / scale, 0.015, 0.35);
    float cover = 1.0 - smoothstep(1.0 - soft, 1.0, chip);
    if (cover <= 0.0) {
      continue;
    }
    cover *= 1.0 - smoothstep(SHARD_LIFE * 0.55, SHARD_LIFE, age);

    // One face is the outside of the shell and the other is the inside, still
    // catching the light it came away from, so a tumbling piece flickers
    // instead of reading as a flat sticker.
    float face = 0.5 + 0.5 * cos(spin * 1.7);
    vec3 tone = mix(uShell * 0.32, uShell * 1.05, face)
              + uGlow * face * 0.22;

    // The broken edge, which is raw shell and catches the light square on.
    // It is the only thing that says a piece has thickness.
    tone += uGlow * smoothstep(0.55, 1.0, chip) * 0.45;

    result.rgb = mix(result.rgb, tone, cover);
    result.a = max(result.a, cover);
  }

  // Dust, after the pieces so it settles in front of them.
  for (int i = 0; i < DUST_COUNT; i++) {
    vec3 h = hash3(vec3(float(i) * 2.9 + 31.0, 1.3, 7.7));

    float phi = h.x * 6.2831853;
    float up = mix(1.0, -0.35, h.y * h.y);
    float ring = sqrt(max(0.0, 1.0 - up * up));
    vec3 outward = vec3(ring * cos(phi), up, ring * sin(phi));

    float turn = mix(PEEL_FIRST - 0.10, PEEL_FIRST + 0.45, 0.5 - 0.5 * up)
               + 0.10 * h.z;
    float age = uCrack - turn;
    if (age <= 0.0 || age > DUST_LIFE) {
      continue;
    }

    vec3 pos = outward * vec3(EGG_RADIUS_XZ, 1.0, EGG_RADIUS_XZ)
             + outward * (age * DUST_SPEED * mix(0.6, 1.6, h.z))
             + vec3(0.0, -DUST_FALL * age * age, 0.0);

    vec3 view = toCamera * (pos - ro);
    if (view.z > -0.05) {
      continue;
    }

    vec2 at = view.xy * FOCAL / (-view.z);
    float scale = DUST_SIZE * mix(0.5, 1.4, h.x) * FOCAL / (-view.z);
    float d = length(uv - at) / scale;

    float cover = (1.0 - smoothstep(1.0 - clamp(pixel / scale, 0.05, 0.9), 1.0, d))
                * (1.0 - smoothstep(DUST_LIFE * 0.4, DUST_LIFE, age));
    if (cover <= 0.0) {
      continue;
    }

    // Lit almost entirely by what it is flying out of.
    vec3 tone = mix(uShell * 0.6, uGlow, 0.55);
    result.rgb = mix(result.rgb, tone, cover);
    result.a = max(result.a, cover);
  }

  return result;
}

/// glowing egg rather than as something in the room.
float spill(vec2 uv) {
  float open = smoothstep(PEEL_FIRST, 1.0, uCrack);
  return open * exp(-length(uv) * 3.0);
}


void main() {
  vec2 frag = FlutterFragCoord().xy;
  // Divided by the egg's own box height rather than this one, so a piece lands
  // exactly where it would have on the egg. This layer is the whole screen and
  // the egg is a small part of it; normalising by this box would shrink the
  // world and the pieces would leave from the wrong place.
  vec2 uv = (frag - 0.5 * uSize) / uUnit;
  uv.y = -uv.y;

  mat3 camera = rotY(uYaw) * rotX(uPitch);
  vec3 ro = camera * vec3(0.0, 0.0, CAMERA_DISTANCE);

  vec4 debris = shardLayer(uv, ro);

  // Light getting out past the shell, over the dark around the egg.
  float glow = spill(uv);
  vec3 color = uGlow * glow * 0.55;
  float alpha = glow * 0.7;

  color = mix(color, debris.rgb, debris.a);
  alpha = max(alpha, debris.a);

  if (alpha <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  fragColor = vec4(color * alpha, alpha); // premultiplied
}
