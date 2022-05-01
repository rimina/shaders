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

struct Material{
  vec3 l;
  vec3 s;
  float shiny;
};

Material M;

vec3 glow = vec3(0.0);


float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}


float cubescape(vec3 p){
  vec3 pp = p;
  float s = length(pp)-2.5;
  
  pp = p;
  for(int i = 0; i < 5; ++i){
    pp = abs(pp)-vec3(0.7, 0.4, 0.8);
    rot(pp.xy, time*0.5);
    rot(pp.xz, time+fft*4.0);
    rot(pp.yx, time*0.5+fft*2.0);
  }
  
  glow += vec3(0.2, 0.4, 0.5)*0.01 / (abs(s)+0.01);
  
  return min(s, box(pp, vec3(0.2, 5.0, 0.2)));
}


float scene(vec3 p){
  vec3 pp = p;
  
  float room = -box(pp, vec3(20.0, 8.0, 20.0));
  
  pp = abs(pp)-vec3(8.0, 5.0, 6.0);
  
  float pilars = box(pp-vec3(5.0, 1.0, 0.0), vec3(10.0, 2.0, 0.5));
  pilars = min(pilars, box(pp-vec3(0.0, 0.0, 5.0), vec3(0.5, 3.0, 8.0)));
  
  pp = p;
  
  float center = cubescape(pp);
  
  
  M.l = vec3(0.4);
  M.s = vec3(0.35, 0.3, 0.3);
  M.shiny = 10.0;
  
  if(center < room && center < pilars){
    M.l = vec3(0.75, 0.9, 1.0);
    M.s = vec3(2.0);
    M.shiny = 2.0;
  }
  
  return min(min(center, pilars), room);
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

float AO(float e, vec3 p, vec3 n){
  
  float o = 1.0;
  for(float i = 0.0; i < 6.0; ++i){
    o -= (i*e - scene(p+n*i*e))/exp2(i);
  }
  
  return max(min(o, 1.0), 0.0);
}

vec3 shade(vec3 p, vec3 rd, vec3 ld, Material mat){
  vec3 n = normals(p);
  
  float lambertian = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float specular = pow(a, mat.shiny);
  
  float ao = (AO(0.5, p, n) + AO(0.1, p, n))*0.8;
  
  return (mat.l*lambertian*0.8 + mat.s*specular*0.4)*ao;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(15.0*cos(time*0.1), 1.0, 15.0*sin(time*0.1));
  vec3 rt = vec3(0.0, 1.0, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(50.0)));

	vec3 col = vec3(1.0);
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  Material mat = M;
  vec3 g = glow;
  
  vec3 lo = vec3(0.0, 0.0, 0.0);
  vec3 ld = normalize(lo-p);
  
  
  if(t < FAR){
    col = shade(p, rd, ld, mat);
  }
  col += glow;
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.6);
  
  col = smoothstep(-0.2, 1.2, col);
  
	out_color = vec4(col, 1.0);
}