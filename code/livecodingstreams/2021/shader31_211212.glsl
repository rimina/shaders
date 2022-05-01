// Copyright 2021-2022 rimina.
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

#define HASHSCALE1 0.1031
#define PI 3.14159265359

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 60;

const vec3 FOG_COLOR = vec3(0.25, 0.35, 0.45)*0.5;

vec3 glow = vec3(0.0);

// 3D noise function (IQ)
/*float noise(vec3 p){
	vec3 ip = floor(p);
    p -= ip;
    vec3 s = vec3(7.0, 157.0, 113.0);
    vec4 h = vec4(0.0, s.yz, s.y+s.z)+dot(ip, s);
    p = p*p*(3.0-2.0*p);
    h = mix(fract(sin(h)*43758.5), fract(sin(h+s.x)*43758.5), p.x);
    h.xy = mix(h.xz, h.yw, p.y);
    return mix(h.x, h.y, p.z);
}*/

float noise(vec3 p){
  vec3 ip = floor(p);
  p -= ip;
  vec3 n1 = texture(texNoise, p.xy).rgb;
  //return mix(n1.r+n1.g, n1.b+n1.b, p.z);
  return mix(n1.x, n1.y, n1.z);
}

float fbm(vec3 p)
{
	float f;
    f  = 0.50000*noise( p ); p = p*2.01;
    f += 0.25000*noise( p ); p = p*2.02; //from iq
    f += 0.12500*noise( p ); p = p*2.03;
    f += 0.06250*noise( p ); p = p*2.04;
    f += 0.03125*noise( p );
	return f;
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec3 pp = p;
  rot(pp.xy, time*0.01);
  
  float volume = fbm(pp+fract(fft*0.25));
  
  glow += vec3(0.8, 0.18, 0.28) * 0.02 / (abs(volume) + 0.01);
  
  return volume;
}

float trace(vec3 ro, vec3 rd){
  float t = 0.0;
  vec3 p = ro;
  for(int i = 0; i < 3; ++i){
    float d = scene(p);
    t += d;
    p += rd*d;
  }
  
  return t;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(1.0, 1.0, 1.0);
  vec3 rt = vec3(1.0, 1.0, 10.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z)*vec3(q, 1.0/radians(60.0)));
 
  
  float volume = trace(ro, rd);
  vec3 col = vec3(volume)*vec3(0.19, 0.22, 0.22) + FOG_COLOR;
  col -= glow*0.65;
  
  col = smoothstep(-0.2, 1.0, col);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.9);
  
  float offset = 0.2;
  float darkness = 0.2;
  float d = distance(uv, vec2(0.5));
  col *= smoothstep(0.8, offset*0.799, d*(darkness + offset));
  
  
	out_color = vec4(col, 1.0);
}