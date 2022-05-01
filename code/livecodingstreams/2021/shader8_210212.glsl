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
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 40.0;
const int STEPS = 64;

vec3 glow = vec3(0.0);

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p) - r;
  return length(max(d, 0.0) + min(max(d.x, max(d.y, d.z)), 0.0));
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  float zz = FAR*2.0+2.0;
  pp.z = mod(pp.z+zz*0.5, zz)-zz*0.5;
  
  for(int i = 0; i < 4; ++i){
    pp = abs(pp) - vec3(5.0, 3.0, 4.0);
    rot(pp.xy, fract(time*0.1));
    rot(pp.xz, fft+time*0.25);
    
  }
  
  float a = box(pp, vec3(1.0, 1.0, FAR));
  float b = box(pp-vec3(2.0, 4.0, 0.0), vec3(1.0, 1.0, FAR));
  float c = sphere(pp-vec3(-2.0, 1.0, 2.0), 1.5);
 
  
  vec3 col = vec3(0.1, 0.6, 0.4);
  
  float m = mod(length(p)+time, 8.0)-4.0;
  if(m < 0.0 && m < -2.0){
    col = col.grb;
  }
  else if(m > 0.0 && m > 2.0){
    col = vec3(0.0);
  }
  
  vec3 g = col*vec3(0.2, 0.1, 0.6)*0.05 / (0.01+abs(a));
  g += col*0.5 / (0.1+abs(b));
  g += col*vec3(0.8, 0.0, 0.1)*0.01 / (0.01+abs(c));
  
  g *= 0.333;
  
  glow += g;
  
  a = max(abs(a), 0.9);
  c = max(abs(c), 0.1);
  
  return min(a, min(b, c));
}

float march(vec3 ro, vec3 rd, out vec3 p){
  p = ro;
  float t = E;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    
    
    if(d < E || t > FAR){
      break;
    }
    
    p += rd*d;
  }
  
  return t;
}


vec4 plas( vec2 v, float time )
{
	float c = 0.5 + sin( v.x * 10.0 ) + cos( sin( time + v.y ) * 20.0 );
	return vec4( sin(c * 0.2 + cos(time)), c * 0.15, cos( c * 0.1 + time / .4 ) * .25, 1.0 );
}
void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, time*2.5);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(z, x));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  
  vec3 p = vec3(0.0);
  float t = march(ro, rd, p);
  
  vec3 col = vec3(0.0);
  
  if(t < FAR){
    col = vec3(0.1, 0.6, 0.8);
  }
  col += glow*0.5;
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.5);
  
  prev = texture(texPreviousFrame, uv*0.5).rgb;
  col = mix(col, prev, 0.5);
 
  
	out_color = vec4(col, 1.0);;
}