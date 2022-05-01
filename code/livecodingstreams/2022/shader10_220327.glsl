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

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 60;

vec3 glow = vec3(0.0);

int M = 0;

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float center(vec3 p, vec3 t, vec3 s, float a){
  vec3 pp = p;
  
  pp -= t;
  rot(pp.xy, a*0.5);
  rot(pp.xz, a*0.5);
  rot(pp.yz, a*0.25);
  return box(pp, s);
}

float scene(vec3 p){
  vec3 pp = p;
  //rot(pp.xz, time*0.25);
  
  float cc = center(pp, vec3(0.0), vec3(1.0), -time);
  
  pp.y = abs(pp.y)-5.0;
  
  float fc = box(pp, vec3(15.0, 2.0, 15.0));
  
  vec3 translate = vec3(0.0, -1.2, 0.0);
  vec3 size = vec3(2.0);
  float invisible = center(pp, translate, size, time);
  
  pp.xz = abs(pp.xz)-vec2(12.0);
  
  float pilar = box(pp, vec3(1.0, 5.2, 1.0));
  
  glow += vec3(0.2, 0.2, 0.5) * 0.01 / (abs(invisible)+0.01);
  
  fc = max(fc, -invisible);
  fc = min(fc, pilar);
  
  M = 0;
  if(cc < fc){
    M = 1;
  }
  
  return min(cc, fc);
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
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

vec3 shade(vec3 p, vec3 rd, vec3 ld, vec3 lc, int m){
  vec3 n = normals(p);
  
  float l = max(dot(ld, n), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, 20.0);
  
  vec3 lamc = vec3(0.3);
  if(m == 1){
    lamc = vec3(0.5, 0.9, 0.9);
    s = pow(a, 40.0);
  }
  
  
  return l*lamc + s*lc;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + uv * 2.0;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(6.0*sin(time*0.1), 0.5, 6.0*cos(time*0.1));
  vec3 rt = vec3(0.0, sin(time*0.1)*0.75, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  int m = M;
  
  vec3 lp = vec3(0.0, 4.0, 0.0);
  vec3 ld = normalize(lp-p);
  vec3 lc = vec3(0.3, 0.3, 0.8);
  
  vec3 ld2 = normalize(-lp-p);
  
  vec3 ld3 = -rd;
  vec3 lc3 = lc.brg;
  vec3 fogc = vec3(uv.x*0.7, (sin(time*0.1)+1.0)*0.125, uv.y*0.8)*0.8;
  vec3 col = fogc;
  if(t < FAR){
    col = shade(p, rd, ld, lc, m);
    col += shade(p, rd, ld2, lc, m);
    col += shade(p, rd, ld3, lc3, m);
    col *= 0.5;
  }
  col += vec3(0.15, 0.25, 0.35);
  col += glow*0.2;
  
  float d = length(p-ro);
  float amount = 1.0 - exp(-d*0.05);
  col = mix(col, fogc, amount);
  
  col = smoothstep(-0.2, 1.2, col);

	out_color = vec4(col, 1.0);
}