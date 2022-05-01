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
uniform sampler2D texRevision;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float time = fGlobalTime;
const float FAR = 100.0;
const int STEPS = 64;
const float E = 0.01;

vec3 glow = vec3(0.0);

float fft = texture(texFFTIntegrated, 0.5).r;

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
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
  
  pp.z = mod(pp.z+40.0, 80.0)-40.0;
  pp.x = mod(pp.x+40.0, 80.0)-40.0;
  
  float scale = 2.2;
  float offset = 16.0;
  for(int i = 0; i < 5; ++i){
    /*pp = abs(pp)-vec3(3.0, 1.0, 5.0);
    rot(pp.xz, time*0.2);
    rot(pp.yz, time*0.1);*/
    
    rot(pp.xz, 0.1*time);
    
    pp = (abs(pp)-vec3(3.0, 2.0, 5.0))*scale-offset*(scale-1.0);
    rot(pp.xz, 0.1*time);
    rot(pp.yz, time*0.1);
    rot(pp.yx, fft);
  }
  
  float a = box(pp, vec3(20.0))*pow(scale, -5.0);
  float b = box(pp, vec3(10.0, 10.0, FAR))*pow(scale, -5.0);
  float c = box(pp-vec3(10.0, 20.0, 0.0), vec3(10.0, 10.0, FAR))*pow(scale, -5.0);
  
  vec3 g = vec3(0.2, 0.4, 0.5)*0.01 / (0.01+abs(a));
  g += vec3(0.5, 0.3, 0.2)*0.05 / (0.01+abs(c));
  
  glow += g;
  
  c = max(abs(c), 0.1);
  
  return min(a, min(b, c));
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t +=d;
    p = ro+rd*t;
    
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
    scene(p+eps.yyx) - scene(p-eps.yyx)
  ));
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 n = normals(p);
  
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float s = pow(a, 10.0);
  
  return l*vec3(0.3, 0.5, 0.9)*0.5+s*vec3(0.3, 0.6, 1.8)*0.5;
  
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.06);
	vec3  fogColor = mix(vec3(0.0, 0.05, 0.05), vec3(0.5, 0.2, 0.15), pow(sunAmount, 7.0));
  return mix(col, fogColor, fogAmount);
}

vec3 render(vec3 ro, vec3 rd){
  float t = march(ro, rd);
  vec3 p = ro+rd*t;
  
  vec3 ld = normalize(vec3(0.0, 0.0, FAR) - ro);
  vec3 ld2 = normalize(ro-vec3(0.0, 0.0, FAR));
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = shade(p, rd, ld);
    col += shade(p, rd, ld2);
    col *= 0.5;
    col += vec3(0.1, 0.5, 0.6);
  }
  col += glow*0.25;
  
  vec3 f = fog(col, p, ro, rd, ld);
  vec3 ff = fog(col, p, ro, rd, ld2);
  f += ff;
  f *= 0.5;
  
  return f;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(1.0, 0.0, time+fft);
  vec3 rt = vec3(1.5, 0.0, -FAR);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, radians(60.0)));
  
  vec3 col = render(ro, rd);
  
  col = pow(col, 1.0/vec3(1.7));

	out_color = vec4(col, 1.0);;
}