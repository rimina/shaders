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
uniform sampler2D texTexBee;
uniform sampler2D texTexOni;

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float FAR = 100.0;
const float E = 0.001;
const int STEP = 30;

vec3 glow = vec3(0.0);

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float sphere(vec3 position, float radius){
  return length(position)-radius;
}

float box(vec3 position, vec3 dimensions){
  vec3 d = abs(position)-dimensions;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rotate(inout vec2 position, float angle){
  position = cos(angle)*position + sin(angle)*vec2(position.y, -position.x);
}

float scene(vec3 position){
  vec3 p = position;
  
  rotate(p.xy, time*0.1);
  rotate(p.yz, time*0.1 + fft*10.0);
  
  p = mod(p + 20.0, 40.0)-20.0;
  
  float safe = sphere(p, 15.0);
  
  float scale = 1.0;
  float offset = 16.0;
  for(int i = 0; i < 7; ++i){
    p = (abs(p) - vec3(2.0)) * scale - offset*(scale-1.0);
    rotate(p.xy, time*0.5);
    rotate(p.xz, fft*20.0);
  }
  
  //box in Finnish is laatikko
  float laatikko = box(p, vec3(20.0, 1.0, 1.0))*pow(scale, -7.0);
  //rotate(p.xy, fft*10.0);
  float laatikko2 = box(p-vec3(0.0, 2.0, 10.0), vec3(1.0, 1.0, 20.0))*pow(scale, -7.0);
  
  //ball in Finnish is pallo
  float pallo = sphere(p- vec3(1.0), 2.0)*pow(scale, -7.0);
  
  vec3 g = vec3(0.7, 0.3, 0.6)*0.05 / (0.01 + abs(laatikko));
  g += vec3(0.8, 0.6, 0.2)*0.05 / (0.01 + abs(laatikko2));
  g += vec3(0.1, 0.8, 0.8)*0.01 / (0.01 + abs(pallo));
  
  g *= 0.333;
  
  glow += g;
  
  pallo = max(abs(pallo), 0.01);
  laatikko = max(abs(laatikko), 0.1);
  laatikko2 = max(abs(laatikko2), 0.1);
  
  return max(min(laatikko, min(laatikko2, pallo)), -safe);
}

float march(vec3 rayOrigin, vec3 rayDirection){
  
  float t = E;
  vec3 position = rayOrigin;
  
  for(int i = 0; i < STEP; ++i){
    float d = scene(position);
    t += d;
    position = rayOrigin + rayDirection * t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
  
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 ceteredUV = -1.0 + 2.0 * uv;
  ceteredUV.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 rayOrigin = vec3(0.0, 0.0, time*0.1);
  vec3 lookAt = vec3(0.0, -2.0, rayOrigin.z + 3.0);
  
  vec3 z = normalize(lookAt - rayOrigin);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rayDirection = normalize(mat3(x, y, z)*vec3(ceteredUV, radians(60.0)));
  
  float t = march(rayOrigin, rayDirection);
  vec3 position = rayOrigin + rayDirection * t;
  
  vec3 col = vec3(0.01, 0.01, 0.02);
  col = glow*0.3;
  
  col = smoothstep(-0.9, 1.9, col);
  
  vec3 previousFrame = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, previousFrame, 0.8);
  

	out_color = vec4(col, 1.0);
}