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

float time = fGlobalTime;
const float E = 0.001;
const int STEP = 64;
const float FAR = 40.0;

float fft = texture(texFFTIntegrated, 1.0).r;

vec3 g = vec3(0.0);

vec3 glow = vec3(0.0);

int material = 0;


layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float sphere(vec3 p, float r){
  return length(p)-1.0;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p) - r;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float scene(vec3 p){
  vec3 pp = p;
  
  rot(pp.xy, time*0.1);
  
  //for(){ p = abs(p) - 0.4; p = rot(p); }
  for(int i = 0; i < 8; ++i){
    pp = abs(pp) - vec3(5.0, 1.5, 2.0);
    rot(pp.xz, time*0.1);
    rot(pp.xy, fft*0.5);
    rot(pp.yz, fft*0.5+time*0.2);
  }
  
  float b = box(pp, vec3(1.5));
  float s = box(pp, vec3(0.5, 1.0, 2.0));
  
  float safe = sphere(p, 10.0);
  s = max(s, -safe);
  b = max(b, -safe);
  
  float pallo = sphere(p, 1.0);
  
  glow += vec3(0.2, 0.1, 0.3) * 0.1 / (0.01+abs(b));
  g += vec3(0.8, 0.5, 0.6) * 0.05 / (0.05+abs(pallo));
  
  b = max(abs(b), 0.9);
  pallo = max(abs(pallo), 0.1);
  
  if(pallo < s && pallo < b){
    material = 1;
  }
  else{
    material = 0;
  }
  
  return min(pallo, min(s, b));
}


float march(vec3 ro, vec3 rd, out vec3 p, out bool hit){
  p = ro;
  float t = 0.0;
  hit = false;
  
  for(int i = 0; i < STEP; ++i){
    float d = scene(p);
    p += rd*d;
    t += d;
    
    if(d < E || t > FAR){
      break;
    }
  }
  if(t < FAR){
    hit = true;
  }
  
  return t;
}


void main(void)
{
  vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(1.8, -2.0, 1.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, radians(60.0)));
  bool hit = false;
  vec3 p = vec3(0.0);
  
  float t = march(ro, rd, p, hit);
  
  vec3 col = vec3(0.2, 0.1, 0.4);
  if(hit){
    if(material == 1){
      col += vec3(0.8, 0.1, 0.1)*g;
    }
    else{
      float m = mod(t+4.0, 6.0)-4.0;
      col += vec3(0.5, 0.6, 0.8)-t/FAR;
      if(m > 0.0 && m > 2.0){
        col = col.brg;
      }
      else if( m < 0.0 && m < -2.0){
        col = col.gbb;
      }
      
      col += glow*vec3(0.2, 0.3, 0.6);
    }
  }
  else{
    col +=vec3(0.8, 0.5, 0.8) * g;
    col +=vec3(0.3, 0.8, 0.8) * glow;
    col *= 0.5;
  }
  
  //col = 1.0 -col;
    
 
  vec3 last = texture(texPreviousFrame, uv).rgb;
  vec2 uuv = vec2(dFdx(last.y), dFdy(last.y));
  last = texture(texPreviousFrame, uuv+uv).rgb;
  //col += last*0.5;
  col = mix(col, last, vec3(0.4, 0.3, 0.6));
  
  col = smoothstep(-0.2, 1.2, col);
  
  col = pow(col, 1.0/vec3(2.2));
  out_color = vec4(col, 1.0);
}