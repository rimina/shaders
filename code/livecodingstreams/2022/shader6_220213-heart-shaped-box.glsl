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

#define PI 3.14159265

float time = fGlobalTime;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 64;

int M = 0;

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float cappedCylinder(vec3 p, float h, float r){
  vec2 d = abs(vec2(length(p.xz), p.y))-vec2(h, r);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float heart(vec3 p, float height){
  vec3 pp = p;
  pp.x = abs(pp.x)-1.4;
  rot(pp.xz, -PI*0.22);
  
  float kaari = cappedCylinder(pp, 1.61, height);
  pp -= vec3(-2., 0.0, 0.6);
  
  float kulma = box(pp, vec3(2.0, height, 1.01));
  
  return min(kaari, kulma);
  
}

float scene(vec3 p){
  vec3 pp = p;
  
  pp += vec3(time, 0.0, 0.0);
  
  pp.x = mod(pp.x+4.0, 8.0)-4.0;
  
  rot(pp.yz, PI*0.22);
  float heartBox =  heart(pp, 0.6);
  pp -= vec3(0.0, 0.5, 0.0);
  pp *= 0.98;
  float heartLid = heart(pp, 0.2);
  float hbox = min(heartBox, heartLid);
  

  rot(pp.xz, 0.4);
  vec2 m = mod(pp.xz, 4.0)-1.0;
  if((m.y < -0.5 && m.y >-2.0) || (m.y > 0.25 && m.y < 0.75)){
    M = 1;
  }
  else{
    M = 0;
  }

  return hbox;
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

vec3 normals(vec3 p, float epsilon){
  vec3 e = vec3(epsilon, 0.0, 0.0);
  
  return normalize(vec3(
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

//From Flopine
//https://www.shadertoy.com/view/sdfyWl
float ao(float e, vec3 p, vec3 n){
  return scene(p+e*n)/e;
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 coll = vec3(0.8, 0.4, 0.5)*0.5;
  vec3 cols = vec3(0.8, 0.0, 0.0);
  float shiny = 20.0;
  
  if(M != 0){
    coll = vec3(1.0, 0.4, 0.5)*0.25;
    shiny = 4.0;
  }
  
  vec3 n = normals(p, E);
  float lamb = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float spec = pow(a, shiny);
  
  float aoc = ao(0.1, p, n) + ao(0.2, p, n) + ao(0.5, p, n);
  
  return (coll * lamb + cols * spec)*aoc;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 10.0);
  vec3 rt = vec3(0.0, 0.0, -FAR);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, 1.0/radians(60.0)));
  
  
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  vec3 ld = -z;
  
  vec3 col = vec3(0.9, 0.7, 0.9);
  if(t < FAR){
    col = shade(p, rd, ld);
  }
  
  col = smoothstep(-0.2, 1.0, col);
  col *= smoothstep(0.8, 0.1*0.799, distance(uv, vec2(0.5))*(0.6 + 0.1));
  

	out_color = vec4(col, 1.0);
}