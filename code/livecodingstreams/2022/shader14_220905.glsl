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
const int STEPS = 60;

vec3 glow = vec3(0.);

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.);
}

void rot(inout vec2 p, float a){
  p = p*sin(a) + vec2(p.y, -p.x)*cos(a);
}

float scene(vec3 p){
  vec3 pp = p;
  
  float b = box(pp-vec3(0.0, -5., 0.0), vec3(10.0, 0.5, 10.0));
  for(int i = 0; i < 5; ++i){
    pp = abs(pp) - vec3(0.5, 0.7, 0.5);
    rot(pp.xy, time*0.5);
    rot(pp.yz, time*0.25 + fft * 2.0);
    rot(pp.xz, time*0.1 + fft * 5.);
  }
  
  float c = box(pp, vec3(0.2, 1.1, 0.1));
  float d = box(pp, vec3(0.1, 0.1, FAR));
  
  vec3 g = vec3(0.8, 0.4, 0.2) * 0.01 / (abs(c)+0.2);
  g += vec3(0.8, 0.2, 0.4) * 0.02 / (abs(d)+0.02);
  
  g *= 0.5;
  glow += g;
  
  
  d = max(abs(d), 0.5);
  
  float safe = length(p)-1.0;
  
  return max(min(b, min(c, d)), -safe);
}

float march(vec3 ro, vec3 rd){
  vec3 p = ro;
  float t = E;
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

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 e = vec3(E, 0., 0.);
  vec3 n = normalize(vec3(
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
  
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, 20.);
  
  return vec3(0.2) * l + vec3(0.8) * s;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = uv - 0.5;
	q /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec3 ro = vec3(20.0 * sin(time*0.5), 3.0, 25.0 * cos(time*0.5));
  vec3 rt = vec3(0.0, 0.5, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, 1.0/radians(60.0)));
  
  vec3 col = vec3(0., 0., 0.2);
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  if( t < FAR){
    col = shade(p, rd, -rd);
  }
  
  col += glow*0.5;
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.6);
  col = smoothstep(-0.2, 1.2, col);
  
	out_color = vec4(col, 1.0);
}