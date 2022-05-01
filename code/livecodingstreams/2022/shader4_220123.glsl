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
const int STEPS = 120;
const float FAR = 100.0;


vec3 glow = vec3(0.0);

//THANKS FOR http://mercury.sexy/hg_sdf

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float pMod1(inout float p, float size){
  float hs = size*0.5;
  float c = floor((p + hs)/size);
  p = mod(p + hs, size) - hs;
  return c;
}

vec2 pMod2(inout vec2 p, vec2 size){
  vec2 hs = size*0.5;
  vec2 c = floor((p + hs)/size);
  p = mod(p + hs, size) - hs;
  return c;
}

vec3 pMod3(inout vec3 p, vec3 size){
  vec3 hs = size*0.5;
  vec3 c = floor((p + hs)/size);
  p = mod(p + hs, size) - hs;
  return c;
}

void rot(inout vec2 p, float a){
  p = sin(a)*p + cos(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  
  vec3 pp = p;
  rot(pp.xy, time*0.1);
  vec3 i = pMod3(pp, vec3(13.0, 15.0, 2.0));
  for(int o = 0; o < 3; ++o){
    pp.z = abs(pp.z) - 0.5;
    rot(pp.xz, time*0.5);
    rot(pp.xy, time*0.05);
  }
  
  float boxes = box(pp, vec3(0.5, 5.5, 0.5));
  
  pp = p-vec3(time*0.3, 0.0, -4.0);
  float ii = pMod1(pp.x, 2.0);
  
  float balls = sphere(pp, 1.0);
  
  
  //vec3 clamp(vec3 x, vec3 minVal, vec3 maxVal) 
  vec3 col = clamp(i, vec3(0.1, 0.05, 0.2), vec3(0.9, 0.5, 1.0));
  vec3 col2 = clamp(vec3(ii), vec3(0.1), vec3(0.5, 0.2, 0.9));
  
  vec3 g = col * 0.01 / (abs(boxes)+0.01);
  g += col2 * 0.08 / (abs(balls)+0.01);
  
  glow += g*0.5;
  
  boxes = max(boxes, 0.08);
  balls = max(balls, 0.05);
  
  return min(boxes, balls);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t +=d;
    p = ro + rd * t;
    
    if(d < E || t > FAR){
      break;
    }
    
  }
  
  return t;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0 * uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 4.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(20.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  vec3 col = vec3(0.1);
  col += glow*0.4;
  
  float d = distance(p, ro);
  float a = 1.0 - exp(-d*0.025);
  vec3 fogcolor = clamp(vec3(uv*sin(time*0.25), 0.5*cos(time*0.1)), vec3(0.01, 0.05, 0.25), vec3(0.9, 0.5, 0.9));
  col = mix(col, fogcolor, a);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.7);
  col = smoothstep(-0.2, 1.2, col);
  

	out_color = vec4(col, 1.0);
}