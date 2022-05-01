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

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float FAR = 40.0;
const int STEPS = 180;
const float E = 0.001;
float PIXELR = 0.5/v2Resolution.x;

#define PI 3.14159265
#define TAU (2*PI)

vec2 IID = vec2(0.0);
float ID = 0.0; 

//Color palette function from IQ
//http://www.iquilezles.org/www/articles/palettes/palettes.htm
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d ){
    return a + b*cos( TAU*(c*t+d) );
}

//From HG sdf library: http://mercury.sexy/hg_sdf/

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0.0)?-1.0:1.0;
}

vec2 sgn(vec2 v) {
	return vec2((v.x<0.0)?-1.0:1.0, (v.y<0.0)?-1.0:1.0);
}


float vmax(vec3 v) {
	return max(max(v.x, v.y), v.z);
}


// Box: correct distance to corners
float fBox(vec3 p, vec3 b) {
	vec3 d = abs(p) - b;
	return length(max(d, vec3(0))) + vmax(min(d, vec3(0)));
}
// Cheap Box: distance to corners is overestimated
float fBoxCheap(vec3 p, vec3 b) { //cheap box
	return vmax(abs(p) - b);
}
// Plane with normal n (n is normalized) at some distance from the origin
float fPlane(vec3 p, vec3 n, float distanceFromOrigin) {
	return dot(p, n) + distanceFromOrigin;
}

////////////////////////////////////////////////////////////////
//
//                DOMAIN MANIPULATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// Conventions:
//
// Everything that modifies the domain is named pSomething.
//
// Many operate only on a subset of the three dimensions. For those,
// you must choose the dimensions that you want manipulated
// by supplying e.g. <p.x> or <p.zx>
//
// <inout p> is always the first argument and modified in place.
//
// Many of the operators partition space into cells. An identifier
// or cell index is returned, if possible. This return value is
// intended to be optionally used e.g. as a random seed to change
// parameters of the distance functions inside the cells.
//
// Unless stated otherwise, for cell index 0, <p> is unchanged and cells
// are centered on the origin so objects don't have to be moved to fit.
//
//
////////////////////////////////////////////////////////////////



// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// Repeat around the origin by a fixed angle.
// For easier use, num of repetitions is use to specify the angle.
float pModPolar(inout vec2 p, float repetitions) {
	float angle = 2.0*PI/repetitions;
	float a = atan(p.y, p.x) + angle/2.0;
	float r = length(p);
	float c = floor(a/angle);
	a = mod(a,angle) - angle/2.0;
	p = vec2(cos(a), sin(a))*r;
	// For an odd number of repetitions, fix cell index of the cell in -x direction
	// (cell index would be e.g. -5 and 5 in the two halves of the cell):
	if (abs(c) >= (repetitions/2.0)) c = abs(c);
	return c;
}

// Same, but mirror every second cell at the diagonal as well
vec2 pModGrid2(inout vec2 p, vec2 size) {
	vec2 c = floor((p + size*0.5)/size);
	p = mod(p + size*0.5, size) - size*0.5;
	p *= mod(c,vec2(2.0))*2.0 - vec2(1.0);
	p -= size/2.0;
	if (p.x > p.y) p.xy = p.yx;
	return floor(c/2.0);
}

// Mirror at an axis-aligned plane which is at a specified distance <dist> from the origin.
float pMirror (inout float p, float dist) {
	float s = sgn(p);
	p = abs(p)-dist;
	return s;
}

// Mirror in both dimensions and at the diagonal, yielding one eighth of the space.
// translate by dist before mirroring.
vec2 pMirrorOctant (inout vec2 p, vec2 dist) {
	vec2 s = sgn(p);
	pMirror(p.x, dist.x);
	pMirror(p.y, dist.y);
	if (p.y > p.x)
		p.xy = p.yx;
	return s;
}


float scene(vec3 p){
  
  float ground = fPlane(p, normalize(vec3(0.0, 1.0, 0.0)), 2.0);
  vec3 pp = p;
  
  pR(pp.xz, time*0.1);
  
  vec2 offset = vec2(5.0, 1.0);
  float id = pModPolar(pp.xz, 12.0);
  
  vec2 iid = pModGrid2(pp.xz, offset);
  pp.xz -= offset*0.5;
  vec2 iiid = pMirrorOctant(pp.xz, offset*0.5);
  
  pR(pp.xz, time*0.5+fft*5.0);
  
  float box = fBox(pp, vec3(2.0, 4.5, 1.0));
  float spehre = fBox(pp-vec3(0.0, 2.0, 0.0), vec3(0.5, 5.5, 0.5));
  box = max(box, -spehre);
  
  float guard = -fBoxCheap(pp, vec3(0.5, 4.5, 0.5));
  guard = abs(guard) + 0.5*0.1;
  
  ID = id;
  IID = iid*iid;
  
  return min(min(box, guard), ground);
}


float march(vec3 ro, vec3 rd){
  float t = E;
  float st = 0.0;
  
  float omega = 1.0;//this value depends on the scene
  float prev_radius = 0.0;
  
  float candidate_t = t;
  float candidate_error = 1000.0;
  
  vec3 p = ro;
  float sg = sgn(scene(p));
  
  for(int i = 0; i < STEPS; ++i){
    float sg_radius = sg*scene(p);
    float radius = abs(sg_radius);
    st = sg_radius;
    
    bool fail = omega > 1.0 && (radius + prev_radius) < st;
    if(fail){
      st -= omega * st;
      omega = 1.0;
    }
    else{
      st = sg_radius*omega;
    }
    prev_radius = radius;
    float error = radius / t;
    
    if(!fail && error < candidate_error){
      candidate_t = t;
      candidate_error = error;
    }
    
    if(!fail && error < PIXELR || t > FAR){
      break;
    }
    
    t += st;
    p = ro + rd*t; 
  }
  
  float er = candidate_error;
  for(int j = 0; j < 6; ++j){
    float radius = abs(sg*scene(p));
    p += rd*(radius-er);
    t = length(p-ro);
    er = radius/t;
    
    if( er < candidate_error){
      candidate_t = t;
      candidate_error = er;
    }
  }
  if( t < FAR || candidate_error < PIXELR){
    t = candidate_t;
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

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 n = normals(p);
  float lambertian = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float specular = pow(a, 20.0);
  
  vec3 col = palette(length(IID)+ID, vec3(0.8, 0.5, 0.4), vec3(0.2, 0.4, 0.2), vec3(2.0, 1.0, 1.0), vec3(0.0, 0.25, 0.25));
  
  return col*lambertian + vec3(0.5, 0.5 ,0.8)*col*specular;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 8.0, time*0.5-40.0);
  vec3 rt = vec3(0.0, 0.0, ro.z+10.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = ro+rd*t;
  
  vec3 ld = normalize(ro-vec3(0.0, 0.5, -2.0));
  vec3 ld2 = normalize(p-vec3(0.0, 5.0, 0.0));
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = shade(p, rd, ld);
    col += shade(p, rd, ld2);
  }
  
  float fa = 1.0-exp(-distance(p, ro)*0.05);
  col = mix(col, (vec3(255., 229., 180.)/vec3(225.0)*0.75), fa);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.6);
  
  col = smoothstep(-0.2, 1.2, col);
  
  
	out_color = vec4(col, 1.0);
}