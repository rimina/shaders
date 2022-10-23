// Copyright 2020-2022 rimina.
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
const int STEPS = 34;


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
  
  float safe = sphere(pp, 2.0);
  
  pp = abs(pp)-vec3(1.0);
  
  for(int i = 0; i < 5; ++i){
    pp = abs(pp)-vec3(1.5);
    rot(pp.xz, time*0.1);
    rot(pp.xy, -time*0.1);
    rot(pp.yz, time*0.5);
  }
  
  
  vec3 off = vec3(4.0, 5.0, 4.0);
  pp = mod(pp + off*0.5, off)-off*0.5;
  
  rot(pp.xz, -time);
  
  float cube = box(pp, vec3(1.));
  

  rot(pp.xy, time);
  rot(pp.xz, time);
  float sph = box(pp, vec3(1.01));
  
  return max(-safe, max(-sph, cube));
}

float march(vec3 ro, vec3 rd){
  
  vec3 p = ro;
  float t = E;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += abs(d);
    p += rd * d;
  }
  
  return t;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = uv - 0.5;
	q /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec3 ro = vec3(0., 0., 0.0);
  vec3 rt = vec3(0., 0., -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0., 1., 0.)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(60.0)));
  
  float t = march(ro, rd);
  
  vec3 col = smoothstep(0., 1., 1.0-vec3(t*0.09))+vec3(0.4, 0.2, 0.3);
  col = smoothstep(-0.2, 1.2, col);
  
	out_color = vec4(col, 1.0);
  
  
}