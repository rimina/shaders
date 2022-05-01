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

//Color sceheme
//Theme --> Smartphone
//Shapes
//2d / 3d --> 3D

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 60;

const vec3 BASE_L = vec3(0.8, 0.6, 0.8);
const vec3 BASE_S = vec3(0.9, 0.7, 0.7);
const float BASE_SHINY = 40.0;

const vec3 SCREEN_L = vec3(0.5);
const vec3 SCREEN_S = vec3(0.5, 0.8, 0.8);
const float SCREEN_SHINY = 8.0;

int M = 0;

float box(vec3 p, vec3 b, float r){
  vec3 d = abs(p)-b;
  return length(max(d, vec3(0.0))) + min(max(d.x, max(d.y, d.z)), 0.0) - r;
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}


float screenScene(vec3 p){
  vec3 pp = p;
  M = 2;
  rot(pp.xz, time);
  rot(pp.yz, time);
  rot(pp.xz, radians(10.0));
  //rot(pp.xz, time);
  float s = sphere(pp, 0.6);
  return max(box(pp, vec3(0.5), 0.0), -s);
}

float scene(vec3 p){
  vec3 pp = p;
  rot(pp.yz, radians(-20.0));
  rot(pp.xz, radians(10.0));
  
  float height = 1.0 * 3.0;
  float width = 0.47 * 3.0;
  
  float phone = box(pp, vec3(width, height, 0.2), 0.1);
  float screen = box(pp-vec3(0.0, 0.0, 0.2), vec3(width-0.1, height-0.1, 0.1), 0.1);
  
  M = 0;
  if(screen <= phone){
    M = 1;
  }
  
  return phone;
  
  //return length(p)-1.0;
}

float march(vec3 ro, vec3 rd, bool screen){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = screen ? screenScene(p) : scene(p);
    t += d;
    p = ro + rd*t;
    
    if(d < E || t >= FAR){
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

vec3 screenNormals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    screenScene(p+e.xyy) - screenScene(p-e.xyy),
    screenScene(p+e.yxy) - screenScene(p-e.yxy),
    screenScene(p+e.yyx) - screenScene(p-e.yyx)
  ));
}

vec3 shading(vec3 p, vec3 rd, vec3 ld, int mat, bool screen){
  
  
  vec3 lc = BASE_L;
  vec3 sc = BASE_S;
  float s = BASE_SHINY;
  
  if(mat == 1){
    lc = SCREEN_L;
    sc = SCREEN_S;
    s = SCREEN_SHINY;
  }
  
  else if(mat == 2){
    lc = vec3(0.2, 0.8, 0.8);
    sc = vec3(0.6, 1.0, 1.0);
    s = 10.0;
  }
  
  vec3 n = screen ? screenNormals(p) : normals(p);
  
  float lambertian = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, n), ld), 0.0);
  float specular = pow(a, s);
  
  return lc*lambertian + sc*specular;
}

mat3 camera(vec3 ro, vec3 rt, vec3 up){
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, up));
  vec3 y = normalize(cross(x, z));
  
  return mat3(x, y, z);
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 5.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  mat3 cam = camera(ro, rt, vec3(0.0, 1.0, 0.0));
  vec3 rd = normalize(cam * vec3(q, 1.0/radians(60.0)));
  
  float t = march(ro, rd, false);
  vec3 p = ro + rd *t;
  int mat = M;
  
  vec3 lp = vec3(0.0, -5.0, 0.0);
  vec3 lt = p;
  vec3 ld = normalize(lt-lp);
  
  
  vec3 col = vec3(0.4, 0.4, 0.5);
  if(t < FAR){
    col = shading(p, rd, ld, mat, false);
    //IF WE HIT THE SCREEN?!?
    if(mat == 1){
      //I should do some kind of projection to the screen surface here
      //But I have no idea how to calculate it
      ro = vec3(0.0, 8.0, 8.0);
      rt = vec3(0.0, -1.0, -1.5);
      cam = camera(ro, rt, vec3(0.0, 1.0, 0.0));
      rd = normalize(cam * vec3(q, 1.0/radians(50.0)));
      
      t = march(ro, rd, true);
      p = ro + rd * t;
      mat = M;
      if(t < FAR){
        lp = vec3(2.0*sin(time), 5.0*sin(time), 2.0*cos(time));
        lt = p;
        ld = normalize(lt-lp);
        col += shading(p, rd, ld, mat, true);
        col *= 0.5;
      }
    }
  }
  
  

	out_color = vec4(col, 1.0);
}