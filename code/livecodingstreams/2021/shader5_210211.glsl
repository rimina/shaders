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

float time = fGlobalTime;
const float E = 0.001;
const float FAR = 40.0;
const int STEPS = 64;

float fft = texture(texFFTIntegrated, 1.0).r;

vec3 glow = vec3(0.0);

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
  
  return length(max(d, 0.0)+min(max(d.x, max(d.y, d.z)), 0.0));
  
}

float scene(vec3 p){
  
  vec3 pp = p;
  for(int i = 0; i < 4; ++i){
    pp = abs(pp)-vec3(3.0, 4.0, 5.0);
    rot(pp.xz, fract(time*0.5));
    rot(pp.xy, fft);
    rot(pp.yz, fft+time*0.1);
  }
  
  float a = sphere(pp, 1.0);
  float b = box(pp, vec3(1.0, 0.5, FAR));
  
  float c = box(pp-vec3(1.5, 2.0, 0.0), vec3(1.0, 1.0, FAR));
  
  float s = -sphere(p, 3.0);
  
  vec3 g = vec3(0.5, 0.2, 0.6) * 0.1 / (0.01 + abs(a));
  g += vec3(0.1, 0.0, 0.8) * 0.5 / (0.01 + abs(b));
  g += vec3(0.1, 0.0, 0.3) * 0.01 / (0.01 + abs(c));
  g *= 0.33;
  
  glow += g;
  
  a = max(abs(a), 0.5);
  b = max(abs(b), 0.9);
  
  
  return max(min(c, min(a, b)), s);
}


float march(vec3 ro, vec3 rd){
  vec3 p = ro;
  float t = E;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p += rd*d;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}

vec3 normals(vec3 p){
  vec3 eps = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p+eps.xyy) - scene(p-eps.xyy),
    scene(p+eps.yxy) - scene(p-eps.yxy),
    scene(p+eps.yyx) - scene(p-eps.yyx)));
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 2.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(120.0)));
  
  vec3 col = vec3(0.0);
  
  float t = march(ro, rd);
  vec3 p = ro+rd*t;
  
  vec3 prev = vec3(0.0);
  
  if(t < FAR){
    col = vec3(0.8, 0.2, 0.9);
    vec3 n = normals(p);
    
    prev = texture(texPreviousFrame, n.xz).rgb;
    col = mix(col, prev, 0.5);
    
    col -= t/FAR;
  }
  else{
    prev = texture(texPreviousFrame, uv*0.5+fract(time)*0.1).rgb;
    col += prev;
    col *= 0.5;
  }
  
  col += glow*vec3(0.5, 0.8, 0.8);
  
  
  
  

  
	out_color = vec4(col, 1.0);//f + t;
}