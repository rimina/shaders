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

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texChecker;
uniform sampler2D texNoise;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;

const float E = 0.001;
const int STEPS = 64;
const float FAR = 40.0;

float time = fGlobalTime;

float f = texture(texFFTIntegrated, 0.5).r*100.0;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float sgn(float x){
  return (x < 0)?-1:1;
}

vec3 repeat(vec3 p, vec3 n){
  vec3 pp = p;
  vec3 dif = n*0.5;
  pp = mod(pp+dif, n) - dif;
  
  return pp;
}

float pMirror(inout float p, float dist){
  float s = sgn(p);
  p = abs(p)-dist;
  return s;
}

void pR(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p , vec3 r){
  vec3 d = abs(p)-r;
  return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

//HERE IS MY SCENE
float scene(vec3 p){
  
  float noise = length(texture(texNoise, p.xy*f).rgb);
  
  vec3 pp = p;
  
  pMirror(pp.x, 8.0);
  
  pR(pp.xy, time*0.1+f*0.1);
  pp = repeat(pp, vec3(4.0)); 
  
  pMirror(pp.y, 2.0);
  
  pR(pp.xy, time*0.25+f*0.5);
  
  pMirror(pp.z, 1.0*sin(f)+1.0);
  
  pR(pp.yz, f);
  
  float a = box(pp, vec3(0.5));
  float aa = sphere(p, 2.0);
  float b = box(pp, vec3(1.0, 1.5, 0.25));//-noise*0.1;
  
  return max(-aa, max(b, -a));
}
//THERE WAS MY SCENE

vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  
  float dist = length(p-ro);
  float lightAmount = max(dot(rd, ld), 0.0);
  float fogAmount = 1.0-exp(-dist*0.1);
  vec3 fogColor = mix(vec3(0.0), vec3(0.6, 0.1, 0.2), pow(lightAmount, 2.0));
  return mix(col, fogColor, fogAmount);
}


vec3 normals( vec3 p){
  vec3 eps = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p + eps.xyy)-scene(p - eps.xyy),
    scene(p + eps.yxy)-scene(p - eps.yxy),
    scene(p + eps.yyx)-scene(p - eps.yyx)
  ));
}

vec3 shade(vec3 p, vec3 rd, vec3 ld, vec3 col){
  vec3 n = normals(p);
  float lamb = max(dot(n, ld), 0.0);
  vec3 angle = reflect(n, ld);
  float spec = pow(max(dot(rd, angle), 0.0), 100.0);
  
  return lamb*col.bgr*0.6 + spec*col.grb*0.4 + col*0.8; 
}

vec3 march(in vec3 ro, in vec3 rd, in vec3 ld){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p += rd*d;
    if(d < E || t >= FAR){
      break;
    }
  }
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = vec3(0.7, 0.4, 0.8);
    
    float m = mod(p.z+f*8.0, 8.0)-4.0;
    if(m >= 0.0 && m < -2.0){
      col = col.rbg;
    }
    else if( m < 0.0 && m < -2.0){
      col = col.gbr;
    }
    col = shade(p, rd, ld, col);
  }
  
  col *= (1.0-(t*0.05 + vec3(0.2, 0.8, 0.4)));
  col = fog(col, p, ro, rd, ld);
  
  return col;
}

void main(void)
{
  vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
 
  vec3 ro = vec3(cos(time*0.25), 0.5, sin(time*0.15));
  vec3 rt = vec3(0.0, -1.0, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q.xy, radians(50.0)));
  
  vec3 ld = (rt-ro)/distance(rt, ro);
  
  vec3 col = march(ro, rd, ld);

  col = pow(col, 1.0/vec3(2.2));
  out_color =vec4(col, 1.0); // f + t;
  //out_color =vec4(0.0, 0.0, 0.0, 1.0);
}