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

//FOREST GREEN
//BROWN ROOTS

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 64;

const vec3 FOG_COLOR = vec3(0.3, 0.6, 0.8);
const vec3 LIGHT_COLOR = vec3(1.0, 0.9, 0.3);

int material = 0;

vec3 getGround(){
  return vec3(0.15, 0.5, 0.2);
}

vec3 getTrunk(){
  return vec3(0.4, 0.2, 0.2);
}

vec3 getLeafs(){
  return vec3(0.3, 0.8, 0.4);
}

vec3 getMaterial(int id){
  vec3 col = vec3(1.0);
  if(id == 1){
    col = getTrunk();
  }
  else if(id == 2){
    col = getLeafs();
  }
  else{
    col = getGround();
  }
  
  return col;
}


float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float cylinder(vec3 p, float r, float h){
  float d = length(p.zx)-r;
  return max(d, abs(p.y) - h);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opSmoothUnion( float d1, float d2, float k ){
  float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
  return mix( d2, d1, h ) - k*h*(1.0-h);
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

float sinNoise(vec2 p){
  return 0.5*(sin(p.x) + sin(p.y));
}

float scene(vec3 p){
  vec3 pp = p;
  
  
  //For the plane distortion I have taken some inspiration from here:
  //https://www.shadertoy.com/view/XlSSzK
  float h = 0.0;
  vec2 q = p.xz*0.5;
  float s = 0.5;
  mat2 m = mat2(1.0, -1.0, 1.0, 0.5);
  float a = noise(p*(sqrt(5.0)*0.5 + 0.5)*3.2);
  float b = 3.0;
  for(int i = 0; i < 6; ++i){
    h += s * sinNoise(q+a);
    q = m*q*0.8;
    q += vec2(5.42 + b + cos(a+b), 3.13 + b + sin(a+b));
    s *= 0.52 + 0.2*h;
  }
  h *= 0.3;
  
  float ground = box(pp-vec3(0.0, -1.0, 0.0), vec3(FAR, 0.2, FAR))-h;
  
  vec2 offset = vec2(3.0, 4.0);
  vec2 treeIndex = floor((pp.xz + offset*0.5)/offset*0.5);
  
  pp.xz = mod(pp.xz+offset*0.5, offset)-offset*0.5;
  
  float n = noise(p*(sqrt(5.0)*0.5 + 0.5)*3.2+length(treeIndex)*0.25)*0.2;
  
  float trunk = cylinder(pp-vec3(cos(treeIndex.y)*0.5, -1.0+h, sin(treeIndex.x)*0.25), 0.15+n*0.2, 1.2+h);
  float leafs = sphere(pp-vec3(cos(treeIndex.y)*0.5, 0.4+h, sin(treeIndex.x)*0.25), 0.5-h)-n;
  float guard = -box(pp, vec3(3.0, 4.0, 8.0));
  guard = abs(guard) + 8.0*0.1;
  
  pp = p;
  
  vec2 offset2 = vec2(3.0, 7.0);
  vec2 bushIndex = floor((pp.xz + offset2*0.5)/offset2*0.5);
  
  pp.xz = mod(pp.xz+offset2*0.5, offset2)-offset2*0.5;
  float nn = noise(p*(sqrt(5.0)*0.5 + 0.5)*1.1+length(bushIndex)*0.25)*0.5;
  
  float bush = sphere(pp-vec3(cos(bushIndex.x)*0.2, -0.75+h, sin(bushIndex.y)*0.5), 0.25)-nn;
  
  float guard2 = -box(pp, vec3(3.0, 3.0, 7.0));
  guard2 = abs(guard) + 7.0*0.1;
  
  bush = min(guard2, bush);
  
  float tree = min(trunk, leafs);
  tree = min(guard, tree);
  
  if(trunk < leafs && tree < ground && trunk < bush){
    material = 1;
  }
  else if((leafs < trunk && leafs < ground) || (bush < trunk && bush < ground)){
    material = 2;
  }
  else{
    material = 0;
  }
  
  
  
  
  ground = opSmoothUnion(ground, tree, 0.5);
  ground = opSmoothUnion(bush, ground, 0.1);
  return ground;
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

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.07);
	vec3  fogColor = mix(FOG_COLOR, LIGHT_COLOR, pow(sunAmount, 8.0));
  return mix(col, fogColor, fogAmount);
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, -0.1, 3.5);
  vec3 rt = vec3(0.8, 0.5, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, radians(60.0)));
  
  vec3 lp = vec3(6.0, 8.0, 0.0);
  vec3 lt = ro;
  vec3 ld = normalize(lt-lp);
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = getMaterial(material) * (1.0/t)*0.7;
    //col = vec3(0.15, 0.5, 0.2) * (1.0/t);
  }
  
  col = fog(col, p, ro, rd, ld);
  
  
  col = smoothstep(-0.2, 1.2, col);
  col = pow(smoothstep(0.08, 1.1, col)*smoothstep(0.8, 0.005*0.799, distance(uv, vec2(0.5))*(0.8 + 0.005)), 1.0/vec3(2.2));
  
	out_color = vec4(col, 1.0);
}