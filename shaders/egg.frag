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

uniform float uCrack;      // 0 whole shell, 1 split open
uniform vec3 uCrackGlow;   // what shows through the gaps

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

// How big a broken piece of shell is. Small values shatter the egg into
// gravel, which reads as scribble rather than damage; this leaves roughly a
// dozen pieces over the whole shell.
const float PLATE_SCALE = 2.4;
const float CRACK_SPREAD = 2.6;      // distance the cracks travel at uCrack = 1
const float CRACK_MIN_WIDTH = 0.010; // a hairline, before anything opens
const float CRACK_MAX_WIDTH = 0.120; // pieces visibly apart
const float CRACK_RAGGED = 0.055;    // how far an edge wanders off straight

// When pieces start coming away, as fractions of the crack. The crown goes
// first and the base may never go at all, so the creature is uncovered rather
// than the egg vanishing.
const float PEEL_FIRST = 0.34;
const float PEEL_LAST = 1.35;
// How much a piece's own number moves its turn, so they do not leave in rows.
const float PEEL_SCATTER = 0.22;

// The light inside, as it grows. Kept well short of the shell so the first
// openings show a glow deep in the egg rather than a wall of white.
const float CORE_MIN_RADIUS = 0.18;
const float CORE_MAX_RADIUS = 0.62;

// Broken shell on its way out.
const int SHARD_COUNT = 16;
const float SHARD_SIZE = 0.15;  // half-width where it broke off
const float SHARD_SPEED = 2.3;  // how hard it is thrown clear
const float SHARD_FALL = 2.4;   // and how quickly it drops after
const float SHARD_LIFE = 0.55;  // gone by here, so the reveal is not littered

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

vec3 hash3(vec3 p) {
  return vec3(hash(p), hash(p + 19.19), hash(p + 47.71));
}

/// The piece of shell a point belongs to.
///
/// x: distance to the nearest seam. Zero where two pieces meet and rising
///    toward the middle of one, so thresholding it draws the break lines.
/// y: a settled 0..1 number for this piece, so it can be given its own moment
///    to come away without any of it changing frame to frame.
/// z: how far up the shell the piece sits, which is what makes the top come
///    off first.
///
/// Cells rather than noise because a break encloses something. Noise lines
/// wander and fork everywhere at once and never close into a corner, which is
/// why they read as drawn on the egg rather than as the egg coming apart.
vec3 plateInfo(vec3 p) {
  vec3 cell = floor(p);
  vec3 local = fract(p);

  float nearest = 8.0;
  float second = 8.0;
  vec3 owner = vec3(0.0);

  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      for (int z = -1; z <= 1; z++) {
        vec3 offset = vec3(float(x), float(y), float(z));
        vec3 seed = cell + offset;
        float d = length(offset + hash3(seed) - local);
        if (d < nearest) {
          second = nearest;
          nearest = d;
          owner = seed;
        } else if (d < second) {
          second = d;
        }
      }
    }
  }

  // The gap between the two nearest: it closes to nothing exactly where they
  // meet.
  return vec3(second - nearest, hash(owner), owner.y);
}

/// The space the shell is broken up in.
///
/// Nudged off the lattice first, so a seam wanders the way a break in
/// something brittle does instead of running dead straight.
vec3 shatterSpace(vec3 p) {
  return p * PLATE_SCALE
       + CRACK_RAGGED * vec3(valueNoise(p * 11.0),
                             valueNoise(p * 11.0 + 5.0),
                             valueNoise(p * 11.0 + 9.0));
}

/// Whether this piece of shell has already come away.
///
/// A whole piece leaves at once, so this is a step rather than a fade: half a
/// piece dissolving is not what breaking looks like. The edge it leaves lands
/// on a seam, which is dark already, so nothing shows the hard change.
///
/// Height decides most of the timing, so the shell opens from the crown down,
/// and the piece's own settled number decides the rest, so they do not leave
/// in rows. Pieces low on the egg are timed past the end of the sequence and
/// never leave: the creature is uncovered rather than the egg ceasing to be.
float peelTurn(vec3 plate) {
  float height = clamp(plate.z / (PLATE_SCALE * 1.2), -1.0, 1.0);
  return mix(PEEL_FIRST, PEEL_LAST, 0.5 - 0.5 * height)
       + PEEL_SCATTER * plate.y;
}

float tornAt(vec3 plate) {
  return step(peelTurn(plate), uCrack);
}

/// What a ray finds once it is through an opening.
///
/// This is the whole point of taking a piece away: the light is behind the
/// shell, not painted on it. A ray that gets in crosses the hollow, so the far
/// inner wall shows at its own depth and the opening has thickness.
vec3 insideEgg(vec3 from, vec3 rd) {
  // The far side of the shell, found from within: inside the egg the distance
  // to the surface is the negated one.
  float ti = 0.0;
  for (int i = 0; i < 48; i++) {
    float d = -sdEgg(from + rd * ti);
    if (d < HIT_EPS) {
      break;
    }
    ti += d * STEP_SCALE;
    if (ti > MAX_DIST) {
      break;
    }
  }

  vec3 wall = from + rd * ti;
  // Facing back into the hollow, and lit only by what is in the middle of it.
  // Kept dark: an opening has to look like a hole first and a light second,
  // or the egg turns into a lamp with a pattern on it.
  vec3 wallNormal = -normalAt(wall);
  float lit = max(dot(wallNormal, normalize(-wall)), 0.0);
  float falloff = 1.0 / (1.0 + 2.5 * dot(wall, wall));
  vec3 color = uCrackGlow * lit * falloff * 0.12;

  // The light itself, as a glow rather than a lamp with an edge: how near the
  // ray passes the middle is what decides its brightness. Tight, so most of
  // an opening is dark and only the middle of the egg burns.
  float toCentre = length(from - rd * dot(from, rd));
  float radius = mix(CORE_MIN_RADIUS, CORE_MAX_RADIUS, uCrack);
  float halo = clamp(radius / max(toCentre, 1e-3), 0.0, 1.0);
  color += uCrackGlow * pow(halo, 3.5) * mix(0.35, 2.0, uCrack);

  return color;
}

/// Pieces of shell tumbling away from the egg.
///
/// Deliberately not part of the egg's own shape. A dozen moving pieces in the
/// distance field would cost a cell lookup at every step of every ray, and
/// this is on screen for about a third of a second: drawing them where they
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
    float scale = SHARD_SIZE * FOCAL / (-view.z);

    // Tumbling, which is most of what sells a falling piece.
    float spin = age * (3.0 + 7.0 * h.x) + h.y * 6.2831853;
    float c = cos(spin);
    float s = sin(spin);
    vec2 local = (mat2(c, -s, s, c) * (uv - at)) / scale;

    // A chip with corners rather than a disc: shell does not break into
    // pebbles.
    float chip = max(abs(local.x) * 0.85 + abs(local.y) * 0.65,
                     max(abs(local.x), abs(local.y)) * 0.9);
    float cover = 1.0 - smoothstep(0.82, 1.0, chip);
    if (cover <= 0.0) {
      continue;
    }
    cover *= 1.0 - smoothstep(SHARD_LIFE * 0.55, SHARD_LIFE, age);

    // One face is the outside of the shell and the other is the inside, still
    // catching the light it came away from, so a tumbling piece flickers
    // instead of reading as a flat sticker.
    float face = 0.5 + 0.5 * cos(spin * 1.7);
    vec3 tone = mix(uShell * 0.32, uShell * 1.05, face)
              + uCrackGlow * face * 0.22;

    result.rgb = mix(result.rgb, tone, cover);
    result.a = max(result.a, cover);
  }

  return result;
}

/// Light getting out past the shell.
///
/// Once there are openings the egg stops being a lit object and starts being
/// the source, so the dark around it has to brighten too. Without this the
/// glow stops dead at the silhouette and the egg reads as a picture of a
/// glowing egg rather than as something in the room.
float spill(vec2 uv) {
  float open = smoothstep(PEEL_FIRST, 1.0, uCrack);
  return open * exp(-length(uv) * 3.0);
}

// Defined after main, so main reads as the order things are drawn in.
vec3 shellAt(vec3 p, vec3 rd, vec3 plate);

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
  }

  vec3 color = vec3(0.0);
  vec3 p = ro + rd * (tHit > 0.0 ? tHit : tMin);

  // Which piece of shell this is, and whether it is still there.
  vec3 plate = vec3(8.0, 0.0, 0.0);
  bool torn = false;
  if (uCrack > 0.0 && alpha > 0.0) {
    plate = plateInfo(shatterSpace(p));
    torn = tHit > 0.0 && tornAt(plate) > 0.5;
  }

  if (torn) {
    // Nothing to shade where a piece has gone: the ray carries on into the egg
    // and comes back with what is in there. Stepped in past the surface first,
    // so the march does not immediately call itself a hit.
    color = insideEgg(p + rd * 0.02, rd);
  } else if (alpha > 0.0) {
    color = shellAt(p, rd, plate);
  }

  // Light escaping past the shell, over the egg and the dark around it alike.
  float glow = spill(uv);
  color += uCrackGlow * glow * 0.55;
  alpha = max(alpha, glow * 0.7);

  // Broken shell in front of everything. Drawn last because it is between the
  // egg and the camera, and it has to survive rays that missed the egg.
  vec4 debris = shardLayer(uv, ro);
  color = mix(color, debris.rgb, debris.a);
  alpha = max(alpha, debris.a);

  if (alpha <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  fragColor = vec4(color * alpha, alpha); // premultiplied
}

/// The shell itself, where it is still attached.
vec3 shellAt(vec3 p, vec3 rd, vec3 plate) {
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

  // Everything from here shades a piece of shell that is still attached: the
  // ones that have gone never reach this far.
  if (uCrack > 0.0) {
    float seam = plate.x;

    float reach = uCrack * CRACK_SPREAD;
    float fromCrown = distance(p, vec3(0.0, 1.0, 0.0));
    // Sharper than the pieces are wide, so there is a visible front travelling
    // down the shell rather than the whole egg dimming at once.
    float spread = 1.0 - smoothstep(reach - 0.18, reach, fromCrown);

    // A hairline at first and an open gap by the end. The width doing the work
    // is what makes this read as breaking rather than as a pattern that fades
    // in: the same seams stay put and only get wider.
    float width = mix(CRACK_MIN_WIDTH, CRACK_MAX_WIDTH, uCrack * uCrack);
    float gap = (1.0 - smoothstep(0.0, width, seam)) * spread;

    // A piece does not vanish out of a flat shell. It works loose first:
    // tilting off the light and going into shadow, so by the time it leaves
    // the eye has already been told it was coming away.
    float turn = peelTurn(plate);
    float loosening = smoothstep(turn - 0.22, turn, uCrack);
    color *= 1.0 - 0.60 * loosening;

    // A wider, softer band of shadow either side of a seam. Without it the
    // pieces look painted on; with it they have thickness and an edge.
    float lip = (1.0 - smoothstep(0.0, width * 3.5, seam)) * spread;
    color *= 1.0 - 0.45 * lip;

    color = mix(color, color * 0.06, gap);

    // What is behind the shell, showing through the seams before anything has
    // actually come away. Held back hard at the start: a hairline that already
    // glows is decoration, and the first seconds have to look like damage.
    color += uCrackGlow * gap * pow(uCrack, 2.5) * 0.9;

    // The broken edge of a piece that is still attached catches the light from
    // inside. This is the whole of the thickness the shell has, and without it
    // an opening next door looks cut out with scissors.
    color += uCrackGlow * lip * loosening * pow(uCrack, 2.0) * 0.55;
  }

  return color;
}
