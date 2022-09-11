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


//Huge thanks to the live coding community,
//I've learned so much from you!!

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
float E = 0.001;
float F = 100.;

vec3 glow = vec3(0.);

void rot(inout vec2 p, float a){
  p = sin(a)*p + cos(a)*vec2(p.y, -p.x);
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.)) + min(max(d.x, max(d.y, d.z)), 0.);
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  rot(pp.xy, time*0.2);
  
  float bb = -box(pp, vec3(10.0, 10., F*2.));
  
  pp = p;
  for(int i = 0; i < 5; ++i){
    pp = abs(pp)-vec3(0.5, 0.8, 0.4);
    rot(pp.xy, time*0.5+fft*2.);
    rot(pp.yz, time*0.25+fft*5.);
  }
  
  float bx = box(pp, vec3(0.1, 0.8, 0.1));
  glow += vec3(0., 0.2, 0.3) * 0.01 / (abs(bx)+0.1);
  
  float cc = length(pp)-0.2;
  glow += vec3(0.4, 0.2, 0.1) * 0.01 / (abs(cc)+0.2);
  
  float c = length(p)-1.0;
  
  glow += vec3(0.8, 0.5, 0.) * 0.01 / (abs(c)+0.2);
  
  bx = max(bx, -c);
  
  return min(max(bx, -cc), bb);
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 e = vec3(E, 0., 0.);
  vec3 n = normalize(vec3(
    scene(p+e.xyy)-scene(p-e.xyy),
    scene(p+e.yxy)-scene(p-e.yxy),
    scene(p+e.yyx)-scene(p-e.yyx)
  ));
  
  float l = max(dot(n, -ld), 0.);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, 20.);
  
  vec3 coll = vec3(0.5, 0.2, 0.6);
  vec3 cols = vec3(0.8, 0.6, 0.3);
  
  float m = mod(p.z-time*8., 6.0) - 4.0;
  
  if(m > 0. && m < 1.){
    coll = coll.grb;
  }
  
  return coll*l + cols*s;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = uv-0.5;
	q /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec3 ro = vec3(0., 0.5, 18.);
  vec3 rt = vec3(0., 0., -1.);
  
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0., 1., 0.)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, 1.0/radians(60.)));
  
  float t = E;
  vec3 p = ro;
  for(int i = 0; i < 100; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd * t;
    if(d < E || t > F){
      break;
    }
  }
  
  vec3 ld = normalize(p - vec3(4., 2., -2.));
  
  vec3 col = vec3(0.1, 0.1, 0.2);
  if(t < F){
    col = shade(p, rd, ld);
  }
  col += glow;
  
  col = smoothstep(-0.2, 1.2, col);
  
	out_color = vec4(col, 1.0);
}