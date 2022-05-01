// Copyright 2022 rimina.
// All rights to the likeness of the visuals reserved.

// Any individual parts of the code that produces the visuals is
// available in the public domain or licensed under the MIT license,
// whichever suits you best under your local legislation.

// This is to say: you can NOT use the code as a whole or the visual
// output it produces for any purposes without an explicit permission,
// nor can you remix or adapt the work itself without a permission.*
// You absolutely CANNOT mint any NFTs based on the Work or part of it.
// You CAN however use any individual algorithms or parts of the Code
// for any purpose, commercial or otherwise, without attribution.

// *(In practice, for most reasonable requests, I will gladly grant
//   any wishes to remix or adapt this work :)).

#version 410 core

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)
uniform float fFrameTime; // duration of the last frame, in seconds

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texPreviousFrame; // screenshot of the previous frame
uniform sampler2D texChecker;
uniform sampler2D texNoise;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 64;

vec3 glow = vec3(0.0);

struct Material{
  vec3 lamb;
  vec3 spec;
  float shiny;
};

Material M;

Material getMaterial(int id){
  Material m;
  
  m.lamb = vec3(0.8, 0.5, 0.2);
  m.spec = vec3(0.8, 0.5, 0.2)*1.25;
  m.shiny = 20.0;
  
  if(id == 0){
    m.lamb = vec3(0.0);
    m.spec = m.lamb;
    m.shiny = 100.0;
  }
  
  return m;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec3 pp = p;
  
  pp.y = abs(pp.y) - 20.0;
  float ground = box(pp, vec3(40.0, 1.5, 15.0));
  
  pp.x = abs(pp.x) - 35.0;
  for(int i = 0; i < 3; ++i){
    pp.z = abs(pp.z) - 3.75;
  }
  rot(pp.xz, radians(20.0));
  ground = min(ground, box(pp-vec3(0.0, -10.0, 0.0), vec3(1.0, 10.0, 1.2)));
  
  
  pp = p;
  for(int i = 0; i < 5; ++i){
    pp = abs(pp) - vec3(0.75, 2.0, 1.5);
    rot(pp.xz, time*0.1);
    rot(pp.zy, fft*2.0);
    rot(pp.xy, fft*0.5+time*0.1);
  }
  
  float cubes = box(pp, vec3(5.0, 0.2, 5.0));
  
  glow += vec3(0.8, 0.25, 0.15) * 0.05 / (abs(cubes) + 0.01);
  
  
  if(ground < cubes){
    M = getMaterial(1);
  }
  else{
    M = getMaterial(0);
  }
  
  return ground;
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd * t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  return t;
}

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p + e.xyy) - scene(p - e.xyy),
    scene(p + e.yxy) - scene(p - e.yxy),
    scene(p + e.yyx) - scene(p - e.yyx)
  ));
}

vec3 shade(vec3 rd, vec3 p, vec3 ld, Material m){
  vec3 n = normals(p);
  
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, m.shiny);
  
  return m.lamb*l + m.spec*s;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, -4.0, 37.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, 1.0/radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  vec3 ld = normalize(vec3(0.0, 0.0, -10.0)-p);
  Material m = M;
  
  vec3 gradient = smoothstep(-0.1, 1.0, vec3(length(q)));
  vec3 col = mix(vec3(0.0, 0.1, 0.15), vec3(0.0, 0.0, 0.05) ,gradient);
  if(t < FAR){
    col = shade(rd, p, ld, m);
  }
  
  col += glow;
  
	out_color = vec4(col, 1.0);
}