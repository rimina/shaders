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

//I'm using HG_SDF library! http://mercury.sexy

#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5)*0.5 + 0.5)

#define saturate(x) clamp(x, 0, 1)

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.1).r;

const float E = 0.001;
const int STEPS = 64;
const float FAR = 40.0;

const vec3 BC = vec3(0.3, 0.7, 0.9);
const vec3 FC = vec3(0.2);
const vec3 LC = vec3(0.7, 0.5, 0.3);

int ID = 0;

vec3 glow = vec3(0.0);

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0)?-1:1;
}

float sphere(vec3 position, float radius){
  return length(position)-radius;
}

float box(vec3 position, vec3 dimensions){
  vec3 b = abs(position)-dimensions;
  return length(max(b, 0.0)) + min(max(b.x, max(b.y, b.z)), 0.0); 
  
}

void rotate(inout vec2 position, float angle){
  position = cos(angle) * position + sin(angle) * vec2(position.y, -position.x);
}

// 3D noise function (IQ)
float noise(vec3 p){
	vec3 ip = floor(p);
    p -= ip;
    vec3 s = vec3(7.0,157.0,113.0);
    vec4 h = vec4(0.0, s.yz, s.y+s.z)+dot(ip, s);
    p = p*p*(3.0-2.0*p);
    h = mix(fract(sin(h)*43758.5), fract(sin(h+s.x)*43758.5), p.x);
    h.xy = mix(h.xz, h.yw, p.y);
    return mix(h.x, h.y, p.z);
}

float scene(vec3 position){
  
  vec3 p = position;
  float n = noise(position + time * sqrt(5.0)*0.5 + 0.5);
  
  rotate(p.xy, time*0.1);
  
  for(int i = 0; i < 3; ++i){
    p = abs(p) - vec3(2.0 ,1.0, 2.0);
    rotate(p.xy, radians(30.0) + fract(time));
    rotate(p.xz, fft*15.0);
    rotate(p.yz, 0.1*time+fft);
  }
  
  float a = box(p, vec3(0.25, 0.25, 10.0)) - sin(n)*0.5;
  
  float b = sphere(p - vec3(1.0, 1.0, 0.0), 1.0) - n;
  
  float c = sphere(p -vec3(2.0, 2.0, 0.0), 2.5) - cos(n)*0.5;
  
  float safe = sphere(position, 5.0);
  
  vec3 g = vec3(0.2, 0.7, 0.5) * 0.03 / (0.02 + abs(a));
  g += vec3(0.7, 0.3, 0.3) * 0.08 / (0.01 + abs(b));
  g += vec3(0.2, 0.6, 0.9) * 0.03 / (0.02 + abs(c));
  
  glow += g;
  g *= 0.333;
  
  if(c < a && c < b){
    ID = 1;
  }
  else{
    ID = 0;
  }
  
  a = max(abs(a), 0.1);
  b = max(abs(b), 0.3);
  c = max(abs(c), 0.5);
  
  return max(min(a, min(b, c)), -safe);
}


//Sphere marching loop
float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 position = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(position);
    t +=d;
    position = ro + rd*t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p + e.xyy) - scene(p - e.xyy),
    scene(p + e.yxy) - scene(p - e.yxy),
    scene(p + e.yyx) - scene(p - e.yyx)
  ));
}

vec3 shade(vec3 rd, vec3 p, vec3 ld){
  
  vec3 n = normals(p);
  float lambertian = max(dot(n, ld), 0.0);
  float angle = max(dot(reflect(ld, n), rd), 0.0);
  float specular = pow(angle, 10.0);
  
  float m = mod(p.z - (time+fft*10.0), 8.0) - 4.0;
  vec3 col = BC;
  if(ID == 0){
    if(m < -1.0){
      col = BC.brg;
    }
    else if( m > 1.0){
      col = BC.gbr;
    }
  }
  else{
    col = vec3(1.0, 0.5, 0.5);
  }
  
  return lambertian * col * 0.5 + specular * (col * vec3(1.1, 1.2, 1.2)) * 0.8;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 uvv = -1.0 + 2.0*uv;
  uvv.x *= v2Resolution.x / v2Resolution.y;
  
  vec3 rayOrigin = vec3(sin(fft*20.0)*10.0, -1.2, cos(fft*20.0)*20.0);
  vec3 lookAt = vec3(0.0, 1.5, 0.0);
  
  vec3 z = normalize(lookAt - rayOrigin);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rayDirection = normalize(mat3(x, y, z) * vec3(uvv, radians(60.00)));
  
  vec3 lightDirection = -rayDirection;
  
  vec3 col = vec3(0.0);
  
  float t = march(rayOrigin, rayDirection);
  vec3 position = rayOrigin + t * rayDirection;
  if(t < FAR){
    col = shade(rayDirection, position, lightDirection);
  }
  
  col += glow*0.1;
  
  
  vec4 pcol = vec4(0.0);
  vec2 puv = vec2(20.0/v2Resolution.x, 20.0/v2Resolution.y);
  vec4 kertoimet = vec4(0.1531, 0.12245, 0.0918, 0.051);
  pcol = texture2D(texPreviousFrame, uv) * 0.1633;
  pcol += texture2D(texPreviousFrame, uv) * 0.1633;
  for(int i = 0; i < 4; ++i){
    pcol += texture2D(texPreviousFrame, vec2(uv.x - (float(i)+1.0) * puv.y, uv.y - (float(i)+1.0) * puv.x)) * kertoimet[i] +
    texture2D(texPreviousFrame, vec2(uv.x - (float(i)+1.0) * puv.y, uv.y - (float(i)+1.0) * puv.x)) * kertoimet[i] +
    texture2D(texPreviousFrame, vec2(uv.x + (float(i)+1.0) * puv.y, uv.y + (float(i)+1.0) * puv.x)) * kertoimet[i] +
    texture2D(texPreviousFrame, vec2(uv.x + (float(i)+1.0) * puv.y, uv.y + (float(i)+1.0) * puv.x)) * kertoimet[i];
  }
  col += pcol.rgb;
  col *= 0.25;
  
  col = mix(col, texture2D(texPreviousFrame, uv).rgb, 0.5);
  
  col = smoothstep(-0.2, 1.1, col);
  
	out_color = vec4(col, 1.0);
}