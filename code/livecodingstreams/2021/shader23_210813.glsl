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
const float FAR = 100.0;
const int STEPS = 64;

int ID = 0;

vec3 glow = vec3(0.0);

float sphere(vec3 p, float r){
  return length(p)-r;
}

float plane(vec3 p, vec3 n, float d){
  return dot(p, n) + d;
}

float box(vec3 p, vec3 d){
  vec3 b = abs(p)-d;
  return length(max(b, 0.0)) + min(max(b.x, max(b.y, b.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

//FROM MERCURY SDF LIBRARY http://mercury.sexy
// Reflect space at a plane
float pReflect(inout vec3 p, vec3 planeNormal, float offset) {
	float t = dot(p, planeNormal)+offset;
	if (t < 0) {
		p = p - (2*t)*planeNormal;
	}
	return sign(t);
}

float scene(vec3 p){
  vec3 pp = p;
  
  rot(pp.xy, time*0.5);
  float side = pReflect(pp, vec3(0.0, -1.0, 0.0), 1.0);
  float ground = plane(pp, vec3(0.0, 1.0, 0.0), 3.0);
  
  for(int i = 0; i < 5; ++i){
    pp = abs(pp) - vec3(0.5, 0.25, 0.5)*2.0;
    rot(pp.yz, time);
    rot(pp.xy, fft*10.0);
    
  }
  
  float ball = box(pp-vec3(0.0, 1.5, 0.0), vec3(5.0, 0.5, 0.25));
  
  if(side > 0.0){
    glow += vec3(0.0, 0.8, 0.5) * 0.01 / (abs(ball) + 0.01);
    
  }
  else{
    glow += vec3(0.8, 0.0, 0.5) * 0.01 / (abs(ball) + 0.01);
  }
  
  
  if(ground < ball && side < 0.0){
    ID = 1;
  }
  else if( ground < ball && side >= 0.0){
    ID = 0;
  }
  else if(ball < ground && side < 0.0){
    ID = 2;
  }
  else{
    ID = 3;
  }
  
  return min(ground, ball);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t +=d;
    p = ro + rd*t;
    
    if(t > FAR || d < E){
      break;
    }
  }
  
  return t;
}

vec3 shade(vec3 p){
  vec3 col = vec3(0.6, 0.3, 0.8);
  vec2 m = mod(vec2(p.x+fft*10.0, p.z-time), 8.0)-vec2(0.5, 0.5);
  
  if( ID == 0){
    
    if(m.x*m.y > 0.0){
      col = col.rgr;
    }
    else{
      col = col.grg;
    }
  }
  else if( ID == 1){
    if(m.x*m.y > 0.0){
      col = col.ggr;
    }
    else{
      col = col.rgr;
    }
    
  }
  else if( ID == 3){
    col = 1.0 - col;
  }
  
  if( ID > 1){
    col *= vec3(1.2, 0.5, 1.2);
    
  }
  
  return col;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 15.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  vec3 col = vec3(0.2, 0.1, 0.2);
  
  if(t < FAR){
    col = shade(p)+(1.0/t);
  }
  
  col += glow;
  
  float dist = length(p-ro);
  float fa = 1.0 - exp(-dist*0.04);
  col = mix(col, vec3(0.2, 0.1, 0.3), fa);


	out_color = vec4(col, 1.0);
}