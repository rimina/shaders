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

#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5)*0.5 + 0.5)

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 200.0;
const int STEPS = 60;

float M = 0.0;

const vec3 FOG_COLOR = vec3(0.2, 0.6, 0.6);
const vec3 LIGHT_COLOR = vec3(0.6, 0.8, 0.8);

vec3 glow = vec3(0.0);

//Cats out of something?
layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float cylinder(vec3 p, float r, float lenght){
  float l = length(p.yz) - r;
  l = max(l, abs(p.x) - lenght);
  return l;
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float ellipsoid(vec3 p, vec3 r){
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0*(k0-1.0)/k1;
}

float triangularPrism(vec3 p, vec2 h){
  vec3 q = abs(p);
  return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opSmoothSubtraction( float d1, float d2, float k ){
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float whiskers(vec3 p){
  vec3 pp = p;
  
  
  rot(pp.xy, 0.08*sin(time));
  pp.xy = abs(pp.xy);//-vec2(0.01, 0.01);
  rot(pp.yz, 1.32);
  
  float angle = 2.0*PI / 6.5;
  
  float r = length(pp);
  float a = atan(pp.y, pp.x) + angle*0.5;
  a = mod(a, angle) - angle*0.5;
  
  
  pp.xy = vec2(cos(a), sin(a))*r;
  
  pp.x -= 0.72;
  
  float w = cylinder(pp, 0.015, 0.5);
  
  float cut = -sphere(p, 0.32);
  
  return w;//max(w, cut);
}

float tail(vec3 p){
  vec3 pp = p-vec3(0.9, -1.5, -2.0);
  
  rot(pp.xy, PI*0.4);
  rot(pp.xz, -0.25);
  
  float k = (0.02+0.01*sin(time))*smoothstep(0.0, 1.0, distance(p, pp));
  float c = cos(k*pp.x);
  float s = sin(k*pp.x);
  mat2 m = mat2(c, -s, s, c);
  pp = vec3(m*pp.xy, pp.z);
  
  
  float t = cylinder(pp, 0.18, 3.7);
  
  return t;
  
}

float cat(vec3 p){
  vec3 pp = p;
  float head = sphere(pp, 1.0);
  
  pp.x = abs(pp.x) - 0.45;
  rot(pp.xy, -0.24+0.05*sin(-time));
  float ears = triangularPrism(pp-vec3(0.0, 0.65, 0.0), vec2(0.45, 0.2));
  head = min(ears, head);
  
  pp = p;
  pp.x = abs(pp.x)-0.32;
  rot(pp.xz, -0.02);
  
  float sockets = sphere(pp-vec3(0.0, 0.22, 0.77), 0.2);
  head = opSmoothSubtraction(sockets, head, 0.1);
  float eyes = sphere(pp-vec3(0.0, 0.21, 0.75), 0.17);
  
  pp = p;
  rot(pp.yz, -0.1);
  float nose = ellipsoid(pp-vec3(0.0, -0.1, 0.92), vec3(0.18, 0.14, 0.2));
  
  pp = p;
  float body = ellipsoid(pp-vec3(0.0, -3.0, 0.0), vec3(2.0, 2.5, 2.0));
  float t = tail(pp);
  body = min(body, t);
  
  
  pp = p;
  pp -= vec3(0.0, -0.02, 0.95);
  float w = whiskers(pp);
  
  
  if((nose < body && nose < head && nose < eyes) ||
    (w < body && w < head && w < eyes)){
    M = 2.0;
  }
  else if(eyes < body && eyes < head && eyes < nose){
    M = 1.0;
  }
  else{
    M = 0.0;
  }
  
  glow += vec3(0.2, 0.8, 0.5)*0.01 / (abs(eyes)+0.01);
  
  
  float c = min(head, body);
  c = min(c, eyes);
  c = min(c, nose);
  c = min(c, w);
  return c;
  
}

float scene(vec3 p){
  
  vec3 pp = p;
  rot(pp.xz, -0.4);
  pp -= vec3(0.0, -2.0, time*1.5);
  
  float offset = 10.0;
  
  pp.xz = mod(pp.xz+offset*0.5, offset)-offset*0.5;
  
  float c = cat(pp);
  pp -= vec3(0.0, -3.0, 0.0);
  float b = box(pp, vec3(3.0, 1.5, 3.0));
  b = max(b, -box(pp-vec3(0.0, 0.5, 0.0), vec3(2.8, 1.5, 2.8)));
  
  
  if(b <= c){
    M = 3.0;
  }
  
  return min(b, c);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd*t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}

vec3 getColor(){
  vec3 col = vec3(1.0);
  if(M == 0.0){
    col = vec3(0.1);
  }
  else if(M == 1.0){
    //Orange for eyes
    col = vec3(1.0, 0.6, 0.3);
  }
  else if(M == 2.0){
    //black for nose
    col = vec3(0.0);
  }
  else{
    //box
    col = vec3(0.6, 0.4, 0.8);
  }
  
  return col;
}

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 col = getColor();
  
  vec3 n = normals(p);
  
  float l = max(dot(n, ld), 0.0);
  vec3 a = reflect(n, ld);
  float s = pow(max(dot(rd, a), 0.0), 10.0);
  
  return col * l + col*1.2*s;
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.03);
	vec3  fogColor = mix(FOG_COLOR, LIGHT_COLOR, pow(sunAmount, 16.0));
  return mix(col, fogColor, fogAmount);
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x / v2Resolution.y;
  
  vec3 ro = vec3(4.9, 2.0, 10.0);
  vec3 rt = vec3(-2.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(50.0)));
  
  vec3 col = vec3(0.5);
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  vec3 lp = vec3(-6.0, 8.0, 5.0);
  vec3 lt = ro;
  vec3 ld = normalize(lt-lp);
  
  vec3 ldd = normalize(lp-p);
  
  if(t < FAR){
    col = shade(p, rd, ldd)+(1.0/t)*0.5;
  }
  col += glow;
  col = fog(col, p, ro, rd, ld);

	out_color = vec4(col, 1.0);
}